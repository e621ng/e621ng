import { EngineConfig, SnakeRenderer, html } from "./snake_game";

function rootInit () {
  // if (!/^\/$|^$/.test(window.location.pathname)) return;
  const touchControls = html`
  <div id="touch-container">
    <span id="up">▲</span>
    <span id="left">◀</span>
    <span id="down">▼</span>
    <span id="right">▶</span>
  </div>
  `;
  document.querySelector("head").appendChild(html`<style>
    #touch-container {
      display: grid;
      grid-template: 1fr 1fr 1fr / 1fr 1fr 1fr;
      justify-content: space-evenly;
      align-content: space-evenly;
      align-items: stretch;
      justify-items: stretch;
      & * {
        box-sizing: border-box;
        text-align: center;
      }
    }
    #up {
      grid-row: 1 / 2;
      grid-column: 2 / 3;
    }
    #down {
      grid-row: 3 / 4;
      grid-column: 2 / 3;
    }
    #left {
      grid-row: 2 / 3;
      grid-column: 1 / 2;
    }
    #right {
      grid-row: 2 / 3;
      grid-column: 3 / 4;
    }
  </style>`);
  const canvas = document.createElement("canvas");
  canvas.id = "snake-game";
  // container.prepend(canvas); // document.body.prepend(canvas);
  canvas.width = 300;
  canvas.height = 300;
  var ctx = canvas.getContext("2d");
  if (!ctx) {
    throw Error("Failed to retrieve canvas context.");
  }
  var state = EngineConfig.toUI(EngineConfig.defaults, initialize);
  const container = html`
  <div id=snake-pane>
    ${(() => {
    const t = html`<div id=snake-tab></div>`;
    t.onclick = () => container.setAttribute("set-offscreen", (container.getAttribute("set-offscreen") ?? "true") === "false" ? "true" : "false");
    return t;
  })()}
    <div id=snake-container>
      ${canvas}
      ${touchControls}
      ${state.form}
    </div>
  </div>
  `;
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

if (document.readyState !== "loading") rootInit();
else document.addEventListener("load", rootInit);
