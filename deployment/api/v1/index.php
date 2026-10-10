<?php
require_once dirname(__DIR__, 2) . '/inc.php';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: strict-origin-when-cross-origin');
if ((!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') || (string)($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https') header('Strict-Transport-Security: max-age=63072000');

function api_reply($status, array $payload) {
  http_response_code($status);
  echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE);
  exit;
}

function api_ok(array $data = [], $status = 200) {
  api_reply($status, ['ok' => true] + $data);
}

function api_error($status, $message, $code = null) {
  $payload = ['ok' => false, 'message' => $message];
  if ($code !== null) $payload['code'] = $code;
  api_reply($status, $payload);
}

function api_origin() {
  $https = ((!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') || (string)($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');
  $host = (string)($_SERVER['HTTP_HOST'] ?? 'localhost');
  if (!preg_match('/^[A-Za-z0-9.-]+(?::[0-9]{1,5})?$/D', $host)) $host = 'localhost';
  return ($https ? 'https://' : 'http://') . $host;
}

function api_safe_user($user) {
  if (!$user) return null;
  return [
    'id' => (int)$user['id'],
    'username' => (string)$user['username'],
    'display_name' => (string)$user['display_name'],
    'email' => (string)($user['email'] ?? ''),
    'avatar_url' => !empty($user['avatar']) && preg_match('/^[a-f0-9]{32}\.(jpg|png|webp|gif)$/D', (string)$user['avatar']) ? api_origin() . '/uploads/avatars/' . rawurlencode($user['avatar']) : null,
    'is_verified' => !empty($user['is_verified']),
    'insights_enabled' => function_exists('insights_active') ? insights_active($user) : false,
    'created_at' => $user['created_at'] ?? null,
    'public_url' => api_origin() . '/' . rawurlencode((string)$user['username']),
  ];
}

function api_require_user() {
  $user = me();
  if (!$user) api_error(401, 'يرجى تسجيل الدخول للمتابعة.', 'unauthenticated');
  return $user;
}

function api_rate_login() {
  $key = hash('sha256', (string)($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
  $now = time();
  $entry = $_SESSION['api_login_attempts'][$key] ?? ['started' => $now, 'count' => 0];
  if ($now - (int)$entry['started'] > 900) $entry = ['started' => $now, 'count' => 0];
  if ((int)$entry['count'] >= 8) api_error(429, 'محاولات كثيرة. انتظر قليلًا ثم حاول مجددًا.', 'rate_limited');
  return $key;
}

function api_require_csrf() {
  $provided = (string)($_POST['csrf'] ?? ($_SERVER['HTTP_X_CSRF'] ?? ''));
  $expected = (string)csrf();
  if ($provided === '' || !hash_equals($expected, $provided)) {
    api_reply(419, ['ok' => false, 'code' => 'csrf', 'csrf' => $expected, 'message' => 'تم تحديث رمز الحماية. حاول مجددًا.']);
  }
}

function api_message_stats($userId) {
  global $pdo;
  $stmt = $pdo->prepare('SELECT COUNT(*) total, COALESCE(SUM(is_favorite),0) favorites, COALESCE(SUM(is_question=1),0) questions, COALESCE(SUM(is_question=1 AND answer IS NULL),0) pending, COALESCE(SUM(is_question=1 AND answer IS NOT NULL),0) published, COALESCE(SUM(created_at > NOW() - INTERVAL 1 DAY),0) today FROM messages WHERE recipient_id=? AND is_removed=0');
  $stmt->execute([$userId]);
  $row = $stmt->fetch() ?: [];
  foreach ($row as $key => $value) $row[$key] = (int)$value;
  return $row;
}

function api_public_theme() {
  $colors = [];
  foreach (theme_fields() as $key => $field) {
    $value = (string)setting('theme_' . $key, $field[1]);
    $colors[$key] = preg_match('/^#[0-9a-fA-F]{6}$/D', $value) ? strtolower($value) : $field[1];
  }
  return [
    'colors' => $colors,
    'radius' => max(0, min(24, (int)setting('ui_radius', '8'))),
  ];
}

$method = strtoupper((string)($_SERVER['REQUEST_METHOD'] ?? 'GET'));
$requestPath = parse_url((string)($_SERVER['REQUEST_URI'] ?? '/api/v1'), PHP_URL_PATH) ?: '/api/v1';
$scriptDir = rtrim(str_replace('\\', '/', dirname((string)($_SERVER['SCRIPT_NAME'] ?? '/api/v1/index.php'))), '/');
$route = isset($_GET['r']) ? '/' . trim((string)$_GET['r'], '/') : substr($requestPath, strlen($scriptDir));
$route = '/' . trim($route, '/');
if ($route === '/') $route = '/session';

try {
  if ($method === 'POST') api_require_csrf();

  if ($method === 'GET' && $route === '/app-theme') {
    api_ok(['theme' => api_public_theme()]);
  }

  if ($method === 'GET' && $route === '/session') {
    $user = me();
    api_ok(['csrf' => csrf(), 'user' => api_safe_user($user)]);
  }

  if ($method === 'POST' && $route === '/auth/login') {
    $key = api_rate_login();
    $identifier = strtolower(trim((string)($_POST['identifier'] ?? '')));
    $password = (string)($_POST['password'] ?? '');
    if ($identifier === '' || strlen($identifier) > 190 || strlen($password) > 1024) api_error(422, 'أدخل البريد أو اسم المستخدم وكلمة المرور.');
    $stmt = $pdo->prepare('SELECT * FROM users WHERE email=? OR username=? LIMIT 1');
    $stmt->execute([$identifier, $identifier]);
    $user = $stmt->fetch();
    if (!$user || !password_verify($password, (string)$user['password_hash'])) {
      $_SESSION['api_login_attempts'][$key] = ['started' => time(), 'count' => (int)($_SESSION['api_login_attempts'][$key]['count'] ?? 0) + 1];
      api_error(401, 'بيانات تسجيل الدخول غير صحيحة.', 'invalid_credentials');
    }
    if (!empty($user['is_disabled'])) api_error(403, 'هذا الحساب معطّل. تواصل مع الإدارة.', 'account_disabled');
    session_regenerate_id(true);
    $_SESSION['uid'] = (int)$user['id'];
    unset($_SESSION['api_login_attempts']);
    $user = me();
    api_ok(['csrf' => csrf(), 'user' => api_safe_user($user)]);
  }

  if ($method === 'POST' && $route === '/auth/register') {
    if (setting('allow_register', '1') !== '1') api_error(403, 'التسجيل مغلق حاليًا.');
    $name = trim((string)($_POST['name'] ?? ''));
    $username = strtolower(trim((string)($_POST['username'] ?? '')));
    $email = strtolower(trim((string)($_POST['email'] ?? '')));
    $password = (string)($_POST['password'] ?? '');
    if (mb_strlen($name) < 2 || mb_strlen($name) > 80) api_error(422, 'الاسم الظاهر يجب أن يكون بين حرفين و٨٠ حرفًا.');
    if (!preg_match('/^[a-z0-9_]{3,30}$/D', $username)) api_error(422, 'اسم المستخدم من ٣ إلى ٣٠ حرفًا إنجليزيًا أو رقمًا أو _.');
    $reserved = array_filter(array_map('trim', explode("\n", strtolower(setting('reserved_usernames', "admin\nadministrator\nroot\nsupport\nasrar")))));
    if (in_array($username, $reserved, true)) api_error(422, 'اسم المستخدم محجوز.');
    if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 190) api_error(422, 'البريد الإلكتروني غير صالح.');
    if (strlen($password) < 8 || strlen($password) > 1024) api_error(422, 'كلمة المرور يجب ألا تقل عن ٨ أحرف.');
    $stmt = $pdo->prepare('SELECT id FROM users WHERE username=? OR email=? LIMIT 1');
    $stmt->execute([$username, $email]);
    if ($stmt->fetch()) api_error(409, 'اسم المستخدم أو البريد مستخدم بالفعل.');
    $pdo->prepare('INSERT INTO users(username,display_name,email,password_hash) VALUES(?,?,?,?)')->execute([$username, $name, $email, password_hash($password, PASSWORD_DEFAULT)]);
    session_regenerate_id(true);
    $_SESSION['uid'] = (int)$pdo->lastInsertId();
    api_ok(['csrf' => csrf(), 'user' => api_safe_user(me())], 201);
  }

  if ($method === 'POST' && $route === '/auth/logout') {
    $_SESSION = [];
    if (ini_get('session.use_cookies')) {
      $params = session_get_cookie_params();
      $cookieOptions = ['expires' => time() - 42000, 'path' => ($params['path'] ?? '/') ?: '/', 'secure' => !empty($params['secure']), 'httponly' => true, 'samesite' => 'Lax'];
      if (!empty($params['domain'])) $cookieOptions['domain'] = $params['domain'];
      setcookie(session_name(), '', $cookieOptions);
    }
    remember_clear();
    session_destroy();
    api_ok();
  }

  if ($method === 'GET' && $route === '/public-profile') {
    $username = strtolower(trim((string)($_GET['username'] ?? '')));
    if (!preg_match('/^[a-z0-9_]{3,30}$/D', $username)) api_error(422, 'رابط المستخدم غير صالح.');
    $stmt = $pdo->prepare('SELECT id,username,display_name,avatar,is_disabled,is_verified FROM users WHERE username=? LIMIT 1');
    $stmt->execute([$username]);
    $profile = $stmt->fetch();
    if (!$profile || !empty($profile['is_disabled'])) api_error(404, 'لم نعثر على هذا الحساب.');
    api_ok(['profile' => ['username' => (string)$profile['username'], 'display_name' => (string)$profile['display_name'], 'avatar_url' => !empty($profile['avatar']) && preg_match('/^[a-f0-9]{32}\.(jpg|png|webp|gif)$/D', (string)$profile['avatar']) ? api_origin() . '/uploads/avatars/' . rawurlencode($profile['avatar']) : null, 'is_verified' => !empty($profile['is_verified'])]]);
  }

  if ($method === 'POST' && $route === '/public-messages') {
    global $pdo;
    if (setting('messages_open', '1') !== '1') api_error(403, 'استقبال الرسائل متوقف مؤقتًا.');
    $username = strtolower(trim((string)($_POST['username'] ?? '')));
    $body = trim((string)($_POST['body'] ?? ''));
    $kind = (($_POST['kind'] ?? 'message') === 'question') ? 1 : 0;
    if (!preg_match('/^[a-z0-9_]{3,30}$/D', $username)) api_error(422, 'اسم المستخدم غير صالح.');
    $stmt = $pdo->prepare('SELECT id,display_name,is_disabled FROM users WHERE username=? LIMIT 1');
    $stmt->execute([$username]);
    $recipient = $stmt->fetch();
    if (!$recipient || !empty($recipient['is_disabled'])) api_error(404, 'لم نعثر على هذا الحساب.');
    $maxLen = max(50, min(5000, (int)setting('max_len', '1000')));
    if (mb_strlen($body) < 2 || mb_strlen($body) > $maxLen) api_error(422, 'الرسالة يجب أن تكون بين حرفين و' . $maxLen . ' حرف.');
    if (find_banned_word($body) !== null) api_error(422, 'تحتوي الرسالة على كلمات غير مسموح بها.');
    $ipHash = sender_hash();
    $count = $pdo->prepare('SELECT COUNT(*) FROM messages WHERE sender_ip_hash=? AND created_at > NOW() - INTERVAL 10 MINUTE');
    $count->execute([$ipHash]);
    if ((int)$count->fetchColumn() >= max(1, (int)setting('rate_limit', '10'))) api_error(429, 'أرسلت رسائل كثيرة خلال وقت قصير. انتظر قليلًا.');
    $banned = $pdo->prepare('SELECT 1 FROM sender_bans WHERE ip_hash=? LIMIT 1');
    $banned->execute([$ipHash]);
    if ($banned->fetchColumn()) api_error(403, 'تم إيقاف الإرسال من جهازك بسبب مخالفة سياسة الاستخدام.');
    $pdo->prepare('INSERT INTO messages(recipient_id,body,sender_ip_hash,is_question) VALUES(?,?,?,?)')->execute([(int)$recipient['id'], $body, $ipHash, $kind]);
    $messageId = (int)$pdo->lastInsertId();
    try { if (function_exists('save_message_meta')) save_message_meta($pdo, $messageId); } catch (Throwable $ignored) {}
    try {
      require_once dirname(__DIR__, 2) . '/push_lib.php';
      if (function_exists('push_notify_user')) {
        $preview = setting('push_preview', '1') === '1' ? mb_substr($body, 0, 180) : 'وصلتك رسالة جديدة، افتح صندوقك لقراءتها.';
        push_notify_user((int)$recipient['id'], site_name(), ($kind ? '💬 سؤال جديد: ' : '🔒 رسالة من مجهول: ') . $preview);
      }
    } catch (Throwable $ignored) {}
    api_ok(['message_id' => $messageId, 'sent' => true], 201);
  }

  if ($method === 'GET' && $route === '/inbox') {
    $user = api_require_user();
    $allowedFilters = ['all', 'questions', 'pending', 'published', 'favorites'];
    $filter = in_array((string)($_GET['filter'] ?? 'all'), $allowedFilters, true) ? (string)($_GET['filter'] ?? 'all') : 'all';
    $page = max(1, min(10000, (int)($_GET['page'] ?? 1)));
    $limit = max(1, min(50, (int)($_GET['limit'] ?? 20)));
    $where = 'recipient_id=? AND is_removed=0';
    if ($filter === 'questions') $where .= ' AND is_question=1';
    if ($filter === 'pending') $where .= ' AND is_question=1 AND answer IS NULL';
    if ($filter === 'published') $where .= ' AND is_question=1 AND answer IS NOT NULL';
    if ($filter === 'favorites') $where .= ' AND is_favorite=1';
    $count = $pdo->prepare('SELECT COUNT(*) FROM messages WHERE ' . $where);
    $count->execute([(int)$user['id']]);
    $total = (int)$count->fetchColumn();
    $offset = ($page - 1) * $limit;
    $stmt = $pdo->prepare('SELECT id,body,is_favorite,is_question,answer,answered_at,created_at,audio_path,audio_secs FROM messages WHERE ' . $where . ' ORDER BY created_at DESC,id DESC LIMIT ' . $limit . ' OFFSET ' . $offset);
    $stmt->execute([(int)$user['id']]);
    $messages = [];
    foreach ($stmt->fetchAll() as $row) {
      $messages[] = ['id' => (int)$row['id'], 'body' => (string)$row['body'], 'is_favorite' => !empty($row['is_favorite']), 'is_question' => !empty($row['is_question']), 'answer' => $row['answer'], 'answered_at' => $row['answered_at'], 'created_at' => $row['created_at'], 'is_voice' => !empty($row['audio_path']), 'audio_seconds' => $row['audio_secs'] === null ? null : (int)$row['audio_secs']];
    }
    api_ok(['messages' => $messages, 'stats' => api_message_stats((int)$user['id']), 'pagination' => ['page' => $page, 'limit' => $limit, 'total' => $total, 'has_more' => $offset + count($messages) < $total], 'filter' => $filter]);
  }

  if ($method === 'POST' && preg_match('#^/messages/(\d+)/(favorite|delete|answer|unpublish|report)$#D', $route, $match)) {
    $user = api_require_user();
    $id = (int)$match[1];
    $action = $match[2];
    $owner = (int)$user['id'];
    if ($action === 'favorite') {
      $stmt = $pdo->prepare('UPDATE messages SET is_favorite=1-is_favorite WHERE id=? AND recipient_id=? AND is_removed=0');
      $stmt->execute([$id, $owner]);
      if (!$stmt->rowCount()) {
        $check = $pdo->prepare('SELECT is_favorite FROM messages WHERE id=? AND recipient_id=? AND is_removed=0');
        $check->execute([$id, $owner]);
        $value = $check->fetchColumn();
        if ($value === false) api_error(404, 'لم نعثر على الرسالة.');
      } else {
        $check = $pdo->prepare('SELECT is_favorite FROM messages WHERE id=? AND recipient_id=?');
        $check->execute([$id, $owner]);
        $value = $check->fetchColumn();
      }
      api_ok(['is_favorite' => (bool)$value]);
    }
    if ($action === 'delete') {
      $stmt = $pdo->prepare('SELECT audio_path FROM messages WHERE id=? AND recipient_id=?');
      $stmt->execute([$id, $owner]);
      $audio = $stmt->fetchColumn();
      if ($audio === false) api_error(404, 'لم نعثر على الرسالة.');
      $pdo->prepare('DELETE FROM messages WHERE id=? AND recipient_id=?')->execute([$id, $owner]);
      if ($audio && preg_match('/^[a-f0-9]{32}\.[a-z0-9]{3,4}$/D', (string)$audio)) @unlink(dirname(__DIR__, 2) . '/uploads/voice/' . $audio);
      api_ok();
    }
    if ($action === 'answer' || $action === 'unpublish') {
      $check = $pdo->prepare('SELECT answer FROM messages WHERE id=? AND recipient_id=? AND is_question=1 AND is_removed=0');
      $check->execute([$id, $owner]);
      $question = $check->fetch();
      if (!$question) api_error(404, 'لم نعثر على السؤال.');
      if ($action === 'unpublish') {
        $pdo->prepare('UPDATE messages SET answer=NULL,answered_at=NULL WHERE id=? AND recipient_id=? AND is_question=1')->execute([$id, $owner]);
        api_ok(['answer' => null]);
      }
      $answer = trim((string)($_POST['answer'] ?? ''));
      if (mb_strlen($answer) < 2 || mb_strlen($answer) > 2000) api_error(422, 'الإجابة يجب أن تكون بين حرفين و٢٠٠٠ حرف.');
      if (find_banned_word($answer) !== null) api_error(422, 'تحتوي الإجابة على كلمات غير مسموح بها.');
      $pdo->prepare('UPDATE messages SET answer=?,answered_at=COALESCE(answered_at,NOW()) WHERE id=? AND recipient_id=? AND is_question=1')->execute([$answer, $id, $owner]);
      api_ok(['answer' => $answer]);
    }
    if ($action === 'report') {
      $check = $pdo->prepare('SELECT id FROM messages WHERE id=? AND recipient_id=?');
      $check->execute([$id, $owner]);
      if (!$check->fetchColumn()) api_error(404, 'لم نعثر على الرسالة.');
      $reason = in_array((string)($_POST['reason'] ?? ''), ['harassment', 'threat', 'spam', 'other'], true) ? (string)$_POST['reason'] : 'other';
      $details = mb_substr(trim((string)($_POST['details'] ?? '')), 0, 500);
      $pdo->prepare('INSERT INTO reports(message_id,reporter_id,reason,details) VALUES(?,?,?,?)')->execute([$id, $owner, $reason, $details]);
      api_ok();
    }
  }

  if ($method === 'GET' && $route === '/account') {
    $user = api_require_user();
    api_ok(['user' => api_safe_user($user), 'stats' => api_message_stats((int)$user['id'])]);
  }

  if ($method === 'POST' && $route === '/account/profile') {
    $user = api_require_user();
    $name = trim((string)($_POST['name'] ?? ''));
    if (mb_strlen($name) < 2 || mb_strlen($name) > 80) api_error(422, 'الاسم الظاهر يجب أن يكون بين حرفين و٨٠ حرفًا.');
    if (find_banned_word($name) !== null) api_error(422, 'الاسم يحتوي على كلمات غير مسموح بها.');
    $pdo->prepare('UPDATE users SET display_name=? WHERE id=?')->execute([$name, (int)$user['id']]);
    $stmt = $pdo->prepare('SELECT * FROM users WHERE id=?');
    $stmt->execute([(int)$user['id']]);
    api_ok(['user' => api_safe_user($stmt->fetch())]);
  }

  if ($method === 'POST' && $route === '/account/username') {
    $user = api_require_user();
    $username = strtolower(trim((string)($_POST['username'] ?? '')));
    if (!preg_match('/^[a-z0-9_]{3,30}$/D', $username)) api_error(422, 'اسم المستخدم من ٣ إلى ٣٠ حرفًا إنجليزيًا أو رقمًا أو _.');
    $reserved = array_filter(array_map('trim', explode("\n", strtolower(setting('reserved_usernames', "admin\nadministrator\nroot\nsupport\nasrar")))));
    if (in_array($username, $reserved, true)) api_error(422, 'اسم المستخدم محجوز.');
    $check = $pdo->prepare('SELECT id FROM users WHERE username=? AND id<>? LIMIT 1');
    $check->execute([$username, (int)$user['id']]);
    if ($check->fetchColumn()) api_error(409, 'اسم المستخدم مستخدم بالفعل.');
    $pdo->prepare('UPDATE users SET username=? WHERE id=?')->execute([$username, (int)$user['id']]);
    $stmt = $pdo->prepare('SELECT * FROM users WHERE id=?');
    $stmt->execute([(int)$user['id']]);
    api_ok(['user' => api_safe_user($stmt->fetch())]);
  }

  if ($method === 'POST' && $route === '/account/email') {
    $user = api_require_user();
    $email = strtolower(trim((string)($_POST['email'] ?? '')));
    $current = (string)($_POST['current_password'] ?? '');
    if (!password_verify($current, (string)$user['password_hash'])) api_error(403, 'كلمة المرور الحالية غير صحيحة.');
    if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 190) api_error(422, 'البريد الإلكتروني غير صالح.');
    $check = $pdo->prepare('SELECT id FROM users WHERE email=? AND id<>? LIMIT 1');
    $check->execute([$email, (int)$user['id']]);
    if ($check->fetchColumn()) api_error(409, 'البريد مستخدم بالفعل.');
    $pdo->prepare('UPDATE users SET email=? WHERE id=?')->execute([$email, (int)$user['id']]);
    api_ok();
  }

  if ($method === 'POST' && $route === '/account/password') {
    $user = api_require_user();
    $current = (string)($_POST['current_password'] ?? '');
    $password = (string)($_POST['new_password'] ?? '');
    if (!password_verify($current, (string)$user['password_hash'])) api_error(403, 'كلمة المرور الحالية غير صحيحة.');
    if (strlen($password) < 8 || strlen($password) > 1024) api_error(422, 'كلمة المرور الجديدة يجب ألا تقل عن ٨ أحرف.');
    $pdo->prepare('UPDATE users SET password_hash=? WHERE id=?')->execute([password_hash($password, PASSWORD_DEFAULT), (int)$user['id']]);
    session_regenerate_id(true);
    api_ok(['csrf' => csrf()]);
  }

  if ($method === 'POST' && $route === '/ai/analyze') {
    api_error(410, 'استخدم نقطة التحليل الأصلية /ai_analyze.php بعد عرض موافقة الخصوصية للمستخدم.', 'use_existing_ai_endpoint');
  }

  if ($method === 'OPTIONS') api_reply(204, []);
  api_error(404, 'المسار غير موجود.', 'not_found');
} catch (Throwable $error) {
  error_log('[Sarehny mobile API] ' . get_class($error) . ' on ' . $route);
  api_error(500, 'تعذّر إكمال الطلب الآن. حاول مجددًا.', 'server_error');
}

// لتشغيل تحليل الشخصية استخدم المسار الحالي /ai_analyze.php، مع إرسال action=analyze وconsent=1 وcsrf.
// أبقينا الذكاء الاصطناعي خارج وسيط JSON كي لا يتجاوز موافقة المستخدم أو آلية الحصص الموجودة في السكربت.
?>
