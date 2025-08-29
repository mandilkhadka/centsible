import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log(this)
    setTimeout(() => {
    this.scrollToBottom();
    }, 150);
    document.addEventListener("turbo:after-stream-append", this.scrollToBottom)
  }

  scrollToBottom = () => {
    window.scrollTo(0, document.body.scrollHeight)
  }
}
