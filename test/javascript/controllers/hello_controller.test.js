import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import HelloController from "../../../app/javascript/controllers/hello_controller.js"

describe("HelloController", () => {
  let application

  beforeEach(() => {
    document.body.innerHTML = ""
    application = Application.start()
    application.register("hello", HelloController)
  })

  afterEach(() => {
    application?.stop()
    document.body.innerHTML = ""
  })

  it("writes Hello World! when no name is provided", async () => {
    document.body.innerHTML = `
      <div data-controller="hello">
        <p data-hello-target="output">Loading…</p>
      </div>
    `

    await microtask()

    expect(document.querySelector("[data-hello-target='output']").textContent).toBe(
      "Hello World!"
    )
  })

  it("greets a custom name from data-hello-name", async () => {
    document.body.innerHTML = `
      <div data-controller="hello" data-hello-name="Fred">
        <p data-hello-target="output">Loading…</p>
      </div>
    `

    await microtask()

    expect(document.querySelector("[data-hello-target='output']").textContent).toBe(
      "Hello, Fred!"
    )
  })

  it("falls back to the controller element when no output target exists", async () => {
    document.body.innerHTML = `<div data-controller="hello">Loading…</div>`

    await microtask()

    expect(document.querySelector("[data-controller='hello']").textContent).toBe(
      "Hello World!"
    )
  })
})

function microtask() {
  return Promise.resolve()
}
