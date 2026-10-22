// Sidebar accordion: clicking the title of the section you're already
// on folds/unfolds it, instead of reloading the page. (Stock mdBook only
// folds via the small chevron; clicking the title of the current page
// re-navigates and mdBook re-expands it, so it never closes.) A page's
// own headings ("on this page") fold the same way as its sub-chapters;
// they have no chevron, and the theme hides them on a folded item.
document.addEventListener(
  "click",
  (ev) => {
    const link = ev.target.closest(".chapter-link-wrapper > a:not(.chapter-fold-toggle)");
    if (!link || !link.classList.contains("active")) return;
    const item = link.closest("li.chapter-item");
    const foldable = ":scope > .chapter-link-wrapper > .chapter-fold-toggle, :scope > .on-this-page";
    if (!item || !item.querySelector(foldable)) return;
    ev.preventDefault();
    item.classList.toggle("expanded");
  },
  true,
);
