import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="speech-to-text"
export default class extends Controller {
  static targets = ["input", "button"]

  connect() {
    this.isRecording = false

    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
    this.recognition = new SpeechRecognition()
    this.recognition.continuous = true
    this.recognition.interimResults = true
    this.recognition.lang = "en-US"

    this.recognition.onresult = (event) => {
      let transcript = ""
      for (let i = event.resultIndex; i < event.results.length; i++) {
        transcript += event.results[i][0].transcript
      }
      this.inputTarget.value = transcript
    }

    this.recognition.onend = () => {
      console.log("Speech recognition ended")
      this.isRecording = false
      this.buttonTarget.innerText = "🎤 Speak"
    }
  }

  voiceinput() {
    if (!this.isRecording) {
      this.recognition.start()
      this.isRecording = true
      this.buttonTarget.innerText = "Stop"
      console.log("Recording started")
    } else {
      this.recognition.stop()
      // onend will reset button & state
      console.log("Recording stopped")
    }
  }
}
