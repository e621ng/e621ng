import { EngineConfig, SnakeEngine, SnakeRenderer_default, SnakeRenderer, html } from "./snake_game";

function initialize () {
  if (!/^\/$|^$/.test(window.location.pathname)) return;
  var canvas = /* document.querySelector("canvas") ??  */(() => {
    const c = document.createElement("canvas");
    c.id = "snake-game";
    // container.prepend(c); // document.body.prepend(c);
    return c;
  })();
  canvas.width = 300;
  canvas.height = 300;
  var ctx = canvas.getContext("2d");
  if (!ctx) {
    throw Error("Failed to retrieve canvas context.");
  }
  var state = EngineConfig.toUI(EngineConfig.defaults, initialize);
  /** @type {HTMLDivElement} */
  const container = html`
  <div id=snake-pane>
    <div id=snake-container>
      ${canvas}
      ${state.form}
    </div>
  </div>
  `;
  container.click((e) => container.setAttribute("hidden", container.getAttribute("hidden") ?? "true" === "false" ? "true" : "false"));
  document.body.appendChild(container);
  var lastEngineStats;
  function initialize (cfg) {
    if (lastEngineStats)
      lastEngineStats.remove();
    const r = new SnakeRenderer(
      ctx,
      cfg,
      {
        assets: [
          { identifier: "head", url: "images/snake/head.svg" },
          { identifier: "body", url: "images/snake/body.svg" },
          { identifier: "pellet", url: "images/snake/pelletCentered.svg" },
          { identifier: "bgTile", url: "images/snake/bgTile.png" },
          { identifier: "corner", url: "images/snake/bgCornerTopLeft.png" },
          { identifier: "border", url: "images/snake/bgBorderLeft.png" },
          { identifier: "background", url: "images/snake/scale.svg" },
        ],
        rotateBorders: true,
        makeOverlay: false,
      },
    );
    lastEngineStats = r.engine.renderStats();
    canvas.insertAdjacentElement("afterend", lastEngineStats);
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    r.initGame().then(() => {
      document.onkeyup = (e) => {
        if (e.key === " ") {
          r.startGame();
          document.onkeyup = null;
        }
      };
      r.draw({ engine: r.engine });
    }).catch((error) => {
      console.error("Failed to load game assets:", error);
    });
  }
  // canvas.parentElement.appendChild(state.form);
  initialize(state.defaults);
}

if (document.readyState !== "loading") initialize();
else document.addEventListener("load", initialize);
