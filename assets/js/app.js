// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

let Hooks = {}

Hooks.ScrollChildToBottom = {
    updated() {
        console.log("ScrollChildToBottom hook updated");
        const childElement = this.el.querySelector('.my-class');
        if (childElement) {
            childElement.scrollTop = childElement.scrollHeight;
        }
    }
};

Hooks.ScrollToElementBottom = {
    mounted() {
        console.log("ScrollToElementBottom hook mounted");
        this.scrollToBottom();
    },
    updated() {
        console.log("ScrollToElementBottom hook updated");
        this.scrollToBottom();
    },
    scrollToBottom() {
        const element = this.el;
        const pixelsBelowBottom = element.scrollHeight - element.clientHeight - element.scrollTop;

        if (pixelsBelowBottom < element.clientHeight * 0.3) {
            element.scrollTop = element.scrollHeight;
        }
    }
};

Hooks.ScrollToScreenBottom = {
    mounted() {
        console.log("ScrollToScreenBottom hook mounted");
        window.scrollTo(0, document.body.scrollHeight);
    },
    updated() {
        console.log("ScrollToScreenBottom hook updated");
        const pixelsBelowBottom =
            document.body.scrollHeight - window.innerHeight - window.scrollY;

        // console.log("Pixels below bottom: ", pixelsBelowBottom);
        //console.log("30% of window height: ", window.innerHeight * 0.3);


        if (pixelsBelowBottom < window.innerHeight * 0.3) {
            window.scrollTo(0, document.body.scrollHeight);
        }
    },
};

Hooks.ScrollToBottom = {
    mounted() {
        console.log("ScrollToBottom hook mounted");
        window.scrollTo(0, document.body.scrollHeight);
    },
    updated() {
        console.log("ScrollToBottom hook updated");
        const pixelsBelowBottom =
            document.body.scrollHeight - window.innerHeight - window.scrollY;

        window.scrollTo(0, document.body.scrollHeight);
    },
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, params: { _csrf_token: csrfToken } })

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

