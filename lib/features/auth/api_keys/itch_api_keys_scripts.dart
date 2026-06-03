/// JavaScript, выполняемый в WebView на itch.io/user/settings/api-keys.
abstract final class ItchApiKeysScripts {
  static const extractKeys = '''
(function() {
  function normalizeSource(td) {
    if (!td) return '';
    var text = (td.textContent || '').trim().toLowerCase();
    if (text === 'desktop') return 'desktop';
    if (text === 'web') return 'web';
    return text;
  }
  var rows = document.querySelectorAll('table.nice_table tbody tr');
  var keys = [];
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i];
    var tds = row.querySelectorAll('td');
    if (!tds.length) continue;
    var key = '';
    var hidden = row.querySelector('form input[name="key"]');
    if (hidden && hidden.value) {
      key = hidden.value.trim();
    }
    if (!key) {
      var fullKey = row.querySelector('code.full_key');
      if (fullKey) key = (fullKey.textContent || '').trim();
    }
    if (!key) continue;
    var source = normalizeSource(tds[1]);
    if (key.length > 20) keys.push({key: key, source: source});
  }
  var createForm = null;
  var forms = document.querySelectorAll('form');
  for (var j = 0; j < forms.length; j++) {
    if (forms[j].querySelector('input[name="action"][value="create"]')) {
      createForm = forms[j];
      break;
    }
  }
  var csrf = createForm ? (createForm.querySelector('input[name="csrf_token"]') || {}).value : '';
  return JSON.stringify({keys: keys, csrf: csrf || ''});
})()
''';

  static const submitCreateForm = '''
(function() {
  var forms = document.querySelectorAll('form');
  for (var i = 0; i < forms.length; i++) {
    if (forms[i].querySelector('input[name="action"][value="create"]')) {
      forms[i].submit();
      return 'submitted';
    }
  }
  return 'no_form';
})()
''';
}
