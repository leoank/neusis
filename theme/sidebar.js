// Sidebar accordion: clicking the title of the section you're already
// on folds/unfolds it, instead of reloading the page. (Stock mdBook only
// folds via the small chevron; clicking the title of the current page
// re-navigates and mdBook re-expands it, so it never closes.)
document.addEventListener(
  "click",
  (ev) => {
    const link = ev.target.closest(".chapter-link-wrapper > a:not(.chapter-fold-toggle)");
    if (!link || !link.classList.contains("active")) return;
    if (!link.parentElement.querySelector(".chapter-fold-toggle")) return;
    ev.preventDefault();
    link.closest("li.chapter-item").classList.toggle("expanded");
  },
  true,
);
