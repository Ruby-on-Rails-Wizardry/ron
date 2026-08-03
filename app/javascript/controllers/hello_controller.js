import { Controller } from "@hotwired/stimulus"

// Basic Hotwire Stimulus controller used by the home page and JS unit tests.
export default class extends Controller {
  static targets = ["output"]

  connect() {
    this.greet()
  }

  greet() {
    const message = this.helloMessage

    if (this.hasOutputTarget) {
      this.outputTarget.textContent = message
    } else {
      this.element.textContent = message
    }
  }

  get helloMessage() {
    return this.element.dataset.helloName
      ? `Hello, ${this.element.dataset.helloName}!`
      : "Hello World!"
  }
}
