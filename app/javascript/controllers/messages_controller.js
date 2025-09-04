import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list"]
  connect() {
    setTimeout(() => {
    this.scrollToBottom();
    }, 150);
    document.addEventListener("turbo:after-stream-append", this.scrollToBottom)
  }

  scrollToBottom = () => {
    // this.listTarget.scrollTop = this.listTarget.scrollHeight
    window.scrollTo(0, this.listTarget.scrollHeight)
  }
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".auto-expand").forEach(textarea => {
    const maxHeight = 120; // matches CSS max-height
    textarea.addEventListener("input", () => {
      textarea.style.height = "auto";
      textarea.style.height = Math.min(textarea.scrollHeight, maxHeight) + "px";
    });
  });
});
