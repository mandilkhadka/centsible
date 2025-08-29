import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.scrollToForm()
    document.addEventListener("turbo:after-stream-append", this.scrollToForm)
  }

  disconnect() {
    document.removeEventListener("turbo:after-stream-append", this.scrollToForm)
  }

  scrollToForm = () => {
    const form = document.getElementById("chat-form")
    if (form) {
      form.scrollIntoView({ behavior: "smooth", block: "nearest" })
    }
  }
}
