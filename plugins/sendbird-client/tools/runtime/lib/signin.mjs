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
      text: (el.innerText || el.value || el.getAttribute('aria-label') || '').trim().slice(0, 60),
    };
  });
}

// Picks the sign-in button from describeButtons' list, or null when the page does not say which one
// it is. Rules, in order:
// 1. When the user ID input is in a form, the form's first enabled submit button: the button the
//    browser presses when the user hits Enter (HTML implicit submission uses the form's default
//    button, its first submit button).
// 2. When the form has no submit button, its only enabled button.
// 3. When the input is in no form, the only enabled button on the page.
export function pickSubmit(candidates) {
  const usable = candidates.filter((c) => c.visible && !c.disabled);
  const fieldInForm = candidates.some((c) => c.fieldInForm);
  if (fieldInForm) {
    const inForm = usable.filter((c) => c.inForm);
    const submit = inForm.find((c) => c.submit);
    if (submit) return submit.index;
    if (inForm.length === 1) return inForm[0].index;
    return null;
  }
  return usable.length === 1 ? usable[0].index : null;
}
