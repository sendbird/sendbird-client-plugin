// Finds the button that submits an app's sign-in form without reading its label, so the harness
// signs in to an app in any language ("Sign in", "로그인", "대화 시작하기" all work).
// react.mjs collects one candidate per visible button on the page (describeButtons runs in the
// page) and pickSubmit chooses one; the choice is a pure function so tests run it without a browser.

// Runs in the page (page.evaluate). Tags every button-like element with data-rt-btn=<index> and
// returns, for each, what pickSubmit needs. fieldSelector is the user ID input.
export function describeButtons(fieldSelector) {
  const field = document.querySelector(fieldSelector);
  const form = field ? field.closest('form') : null;
  const all = Array.from(document.querySelectorAll('button, input[type="submit"], input[type="button"], [role="button"]'));
  const shown = (el) => { const r = el.getBoundingClientRect(); const st = window.getComputedStyle(el); return r.width > 0 && r.height > 0 && st.visibility !== 'hidden' && st.display !== 'none'; };
  // the closest box around the user ID input that also holds a shown button: the input's own row
  // (a theme switch or a menu elsewhere on the page is outside it)
  let near = field ? field.parentElement : null;
  while (near && !all.some((el) => near.contains(el) && shown(el))) near = near.parentElement;
  return all.map((el, index) => {
    el.setAttribute('data-rt-btn', String(index));
    const tag = el.tagName.toLowerCase();
    // a <button> without a type attribute is a submit button (HTML button element, type attribute)
    const type = tag === 'button' ? (el.getAttribute('type') || 'submit').toLowerCase()
      : tag === 'input' ? (el.getAttribute('type') || '').toLowerCase() : 'button';
    const rect = el.getBoundingClientRect();
    const style = window.getComputedStyle(el);
    return {
      index,
      submit: (tag === 'button' || tag === 'input') && type === 'submit',
      inForm: !!form && (el.form === form || form.contains(el)),
      disabled: !!el.disabled || el.getAttribute('aria-disabled') === 'true',
      visible: rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none',
      fieldInForm: !!form,
      nearField: !!near && near !== document.body && near !== document.documentElement && near.contains(el),
      loginId: el.getAttribute('data-testid') === 'sb_login_button',
      text: (el.innerText || el.value || el.getAttribute('aria-label') || '').trim().slice(0, 60),
    };
  });
}

// Picks the sign-in button from describeButtons' list, or null when the page does not say which one
// it is. Rules, in order:
// 0. The enabled button with the stable test id sb_login_button (templates/starters-bp/BEST_PRACTICES.md
//    "Stable identifiers"), wherever it is.
// 1. When the user ID input is in a form, the form's first enabled submit button: the button the
//    browser presses when the user hits Enter (HTML implicit submission uses the form's default
//    button, its first submit button).
// 2. When the form has no submit button, its only enabled button.
// 3. When the input is in no form, the only enabled button on the page, or else the only enabled
//    button in the closest box around the input that holds a button (2026-10-24: a starter's sign-in
//    row, input and "Sign in" in one <p>, under a light/dark/system theme switch the design turn added).
export function pickSubmit(candidates) {
  const usable = candidates.filter((c) => c.visible && !c.disabled);
  const tagged = usable.find((c) => c.loginId);
  if (tagged) return tagged.index;
  const fieldInForm = candidates.some((c) => c.fieldInForm);
  if (fieldInForm) {
    const inForm = usable.filter((c) => c.inForm);
    const submit = inForm.find((c) => c.submit);
    if (submit) return submit.index;
    if (inForm.length === 1) return inForm[0].index;
    return null;
  }
  if (usable.length === 1) return usable[0].index;
  const near = usable.filter((c) => c.nearField);
  return near.length === 1 ? near[0].index : null;
}
