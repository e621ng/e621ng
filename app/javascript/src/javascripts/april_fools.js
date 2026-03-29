import { EngineConfig, SnakeRenderer, html } from "./snake_game";
import LStorage from "./utility/storage";

function rootInit () {
  if (!LStorage.Site.Events) {
    return;
  }
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

    #snake-overlay {
      display: flex;
      background-color: rgba(0, 0, 0, 0.5);
      align-items: center;
      justify-content: space-around;
      position: absolute;
      top: 0;
      left: 0;
    }
    .overlay-button {
      background-color: rgba(0, 0, 0, 0.5);
      color: rgba(255, 255, 255, 1);
      width: 3rem;
      height: 3rem;
      font-size: x-large;
    }
  </style>`);
  const canvas = document.createElement("canvas");
  canvas.id = "snake-game";
  canvas.width = 300;
  canvas.height = 300;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw Error("Failed to retrieve canvas context.");
  const state = EngineConfig.toUI(EngineConfig.defaults, initialize);
  const playButton = html`<button id=snake-play class=overlay-button>▶</button>`;
  const overlay = html`
  <span id=snake-overlay>
    ${playButton}
  </span>
  `;
  // Update overlay on canvas change
  (new ResizeObserver((entries, _observer) => {
    const width = canvas.clientWidth || (entries && entries[0] && ((entries[0].borderBoxSize && entries[0].borderBoxSize[0]?.inlineSize) || entries[0].contentRect?.width)) || undefined;
    const height = canvas.clientHeight || (entries && entries[0] && ((entries[0].borderBoxSize && entries[0].borderBoxSize[0]?.blockSize) || entries[0].contentRect?.height)) || undefined;
    const left = canvas.offsetLeft || (entries && entries[0] && entries[0].contentRect?.left) || undefined;
    const top = canvas.offsetTop || (entries && entries[0] && entries[0].contentRect?.top) || undefined;
    if (width) overlay.style.width = `${width}px`;
    if (height) overlay.style.height = `${height}px`;
    if (left) overlay.style.left = `${left}px`;
    if (top) overlay.style.top = `${top}px`;
  })).observe(canvas);
  const container = html`
  <div id=snake-pane>
    ${(() => {
    const t = html`<div id=snake-tab></div>`;
    t.onclick = () => container.setAttribute("set-offscreen", (container.getAttribute("set-offscreen") ?? "true") === "false" ? "true" : "false");
    return t;
  })()}
    <div id=snake-container>
      ${canvas}
      ${overlay}
      ${touchControls}
      ${state.form}
    </div>
  </div>
  `;
  document.body.appendChild(container);
  overlay.style.top = `${canvas.offsetTop}px`;
  overlay.style.left = `${canvas.offsetLeft}px`;
  playButton.addEventListener("click", () => canvas.focus());
  /** @type {HTMLElement} **/ let lastEngineStats;
  function initialize (cfg) {
    if (lastEngineStats)
      lastEngineStats.remove();
    const r = new SnakeRenderer(
      ctx,
      cfg,
      {
        assets: [
          { identifier: "head", url: "/images/snake/head.svg" },
          { identifier: "body", url: "/images/snake/body.svg" },
          { identifier: "pellet", url: "/images/snake/pelletCentered.svg" },
          { identifier: "bgTile", url: "/images/snake/bgTile.png" },
          { identifier: "corner", url: "/images/snake/bgCornerTopLeft.png" },
          { identifier: "border", url: "/images/snake/bgBorderLeft.png" },
          { identifier: "background", url: "/images/snake/scale.svg" },
        ],
        rotateBorders: true,
        makeOverlay: false,
      },
    );
    const toggleOverlay = () => {
        overlay.style.display = r.engine.isGamePaused ? "" : "none";
      },
      playClicked = () => {
        r.engine.isGamePaused ? r.engine.resumeGame() : r.engine.pauseGame();
      },
      changeToReplayButton = () => {
        playButton.innerText = "⟳";
        playButton.onclick = () => {
          state.form.requestSubmit();
          playButton.innerText = "▶";
        };
      };
    r.engine.onGameOver.add(toggleOverlay, changeToReplayButton);
    r.engine.onGamePaused.add(toggleOverlay);
    r.engine.onGameResumed.add(toggleOverlay);

    lastEngineStats = r.engine.renderStats();
    canvas.insertAdjacentElement("afterend", lastEngineStats);
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    r.initGame().then(() => {
      playButton.onclick = () => {
        r.startGame();
        playButton.onclick = playClicked;
      };
      // document.onkeyup = (e) => {
      //   if (e.key === " ") {
      //     r.startGame();
      //     document.onkeyup = null;
      //   }
      // };
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
