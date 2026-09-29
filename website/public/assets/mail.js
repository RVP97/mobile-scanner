// Assemble the support address in the browser so it never sits whole in the HTML.
document.querySelectorAll('[data-u][data-d]').forEach(function (a) {
  var e = a.getAttribute('data-u') + '@' + a.getAttribute('data-d');
  a.href = 'mailto:' + e + '?subject=Lunet';
  if (!a.classList.contains('js-mailbtn')) a.textContent = e;
  a.hidden = false;
});
