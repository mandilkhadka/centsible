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
    this.recognition.lang = "en"

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
      this.buttonTarget.innerHTML = '<i class="fa-solid fa-microphone fa-xl" style="color: rgb(160, 187, 138);""></i>'
    }
  }

  voiceinput() {
    if (!this.isRecording) {
      this.recognition.start()
      this.isRecording = true
      this.buttonTarget.innerHTML = '<i class="fa-solid fa-microphone fa-beat fa-xl" style="color: rgba(44, 72, 19, 0.81);"></i>'
      console.log("Recording started")
    } else {
      this.recognition.stop()
      // onend will reset button & state
      console.log("Recording stopped")
    }
  }
}
