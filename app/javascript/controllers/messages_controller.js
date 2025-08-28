import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="messa
export default class extends Controller {
  connect() {
    this.scrollToBottom()
  }
}
