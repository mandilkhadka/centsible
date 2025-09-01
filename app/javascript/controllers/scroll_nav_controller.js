import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["top", "bottom"]

  connect() {
    this.lastScroll = window.scrollY
    this.onScroll = this.handleScroll.bind(this)
    window.addEventListener("scroll", this.onScroll)
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  handleScroll() {
    const current = window.scrollY
    if (current > this.lastScroll + 5) {
      // scrolling down
      this.topTarget.classList.add("navbar-hidden-top")
      this.bottomTarget.classList.add("navbar-hidden-bottom")
    } else if (current < this.lastScroll - 5) {
      // scrolling up
      this.topTarget.classList.remove("navbar-hidden-top")
      this.bottomTarget.classList.remove("navbar-hidden-bottom")
    }
    this.lastScroll = current
  }
}
