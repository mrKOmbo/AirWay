/**
 * Runs before React hydration to apply the saved theme and avoid a flash.
 * Rendered as a plain <script dangerouslySetInnerHTML> in the <head>.
 */
export function ThemeScript() {
  const code = `
(function() {
  try {
    var saved = localStorage.getItem("aw-theme");
    var theme = saved === "dark" || saved === "light" ? saved : "light";
    document.documentElement.dataset.theme = theme;
  } catch (e) {}
})();
`.trim();

  return (
    // eslint-disable-next-line react/no-danger
    <script dangerouslySetInnerHTML={{ __html: code }} />
  );
}
