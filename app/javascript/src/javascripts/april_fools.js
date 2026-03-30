import { EngineConfig, SnakeRenderer, html } from "./snake_game";
import LStorage from "./utility/storage";

function rootInit () {
  if (!/^\/?$/.test(window.location.pathname)) {
    if (localStorage.getItem("e6.latestTheme") !== "snake") {
      if (/^\/static\/theme\/?$/.test(window.location.pathname)) {
        localStorage.setItem("e6.latestTheme", "snake");
      } else {
        document.querySelector("#nav-themes").className += " notification";
      }
    }
  }
  if (!LStorage.Site.Events) {
    // Does force people who actually did manually select the new embellishment out of it, but whatever, they're no fun anyways.
    if (LStorage.Theme.Extra === "scales" && document.body.getAttribute("data-th-extra") === "scales") {
      document.body.setAttribute("data-th-extra", "hexagon");
    }
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
  let handlingTouchControls = false;
  const markTouchControlInteraction = () => {
    handlingTouchControls = true;
    window.setTimeout(() => {
      handlingTouchControls = false;
    }, 0);
  };
  touchControls.addEventListener("pointerdown", markTouchControlInteraction);
  document.querySelector("head").appendChild(html`<style>
    #snake-container {
      display: flex;
      flex-flow: column;
      justify-content: center;
      gap: 0.5rem;
    }
    #snake-header {
      align-self: center;
      font-size: 0.4rem;
      font-family: monospace;
      background: -webkit-linear-gradient(var(--color-text), var(--color-link-active));
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    #snake-game {
      width: 100%;
      height: 100%;
      display: block;
      align-self: center;
    }
    #snake-game-shell {
      position: relative;
      width: 300px;
      height: 300px;
      align-self: center;
      margin-bottom: 1rem;
    }
    #snake-game-shell::after {
      content: "";
      position: absolute;
      inset: 0;
      background-color: rgba(0, 0, 0, 0.5);
      opacity: 0;
      pointer-events: none;
      transition: opacity 120ms ease;
    }
    #snake-game-shell.is-paused::after {
      opacity: 1;
    }
    #touch-container {
      display: grid;
      grid-template: 1fr 1fr 1fr / 1fr 1fr 1fr;
      grid-template-rows: 3rem 3rem 3rem;
      justify-content: space-evenly;
      align-content: space-evenly;
      align-items: stretch;
      justify-items: stretch;
      gap: 0.25rem;

      & * {
        box-sizing: border-box;
        text-align: center;
        cursor: pointer;
        align-content: center;
        border-radius: 0.25rem;
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

    #snake-play {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      z-index: 1;
      display: none;
      pointer-events: none;
    }
    #snake-game-shell.is-paused #snake-play {
      display: block;
    }
    .overlay-button {
      background-color: rgba(0, 0, 0, 0.5);
      color: rgba(255, 255, 255, 1);
      width: 3rem;
      height: 3rem;
      font-size: x-large;
    }

    #snake-settings {
      position: absolute;
      z-index: -1;
      opacity: 0;
    }

    #engine-stats {
      line-height: 1rem;
    }
    #engine-stats > span {
      font-family: monospace;
      display: flex;
      justify-content: center;
      gap: 1rem;
    }
    #engine-stats > span b {
      width: 5ch;
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
  const canvasShell = html`
  <div id=snake-game-shell class=is-paused>
    ${canvas}
    ${playButton}
  </div>
  `;
  const container = html`
  <div id=snake-pane>
    ${(() => {
    const t = html`<div id=snake-tab></div>`;
    t.onclick = () => container.setAttribute("set-offscreen", (container.getAttribute("set-offscreen") ?? "true") === "false" ? "true" : "false");
    return t;
  })()}
    <div id=snake-container>
      <pre id="snake-header">
 ::::::::  ::::    :::     :::     :::    ::: :::::::::: 
:+:    :+: :+:+:   :+:   :+: :+:   :+:   :+:  :+:        
+:+        :+:+:+  +:+  +:+   +:+  +:+  +:+   +:+        
+#++:++#++ +#+ +:+ +#+ +#++:++#++: +#++:++    +#++:++#   
       +#+ +#+  +#+#+# +#+     +#+ +#+  +#+   +#+        
#+#    #+# #+#   #+#+# #+#     #+# #+#   #+#  #+#        
 ########  ###    #### ###     ### ###    ### ########## 
      </pre>
      ${canvasShell}
      ${touchControls}
      ${state.form}
    </div>
  </div>
  `;
  document.body.appendChild(container);

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
        makePauseOverlay: false,
      },
    );
    playButton.innerText = "▶";
    let hasStarted = false;
    const toggleOverlay = () => {
        canvasShell.classList.toggle("is-paused", !hasStarted || r.engine.isGamePaused);
      },
      shellClicked = () => {
        if (r.engine.isGameOver) {
          hasStarted = false;
          state.form.requestSubmit();
          playButton.innerText = "▶";
          canvasShell.classList.add("is-paused");
          return;
        }

        if (!hasStarted) {
          r.startGame();
          hasStarted = true;
          toggleOverlay();
          canvas.focus();
          return;
        }

        r.engine.isGamePaused ? r.engine.resumeGame() : r.engine.pauseGame();
        canvas.focus();
      },
      changeToReplayButton = () => {
        playButton.innerText = "⟳";
      },
      triggerPause = (e) => {
        if (handlingTouchControls || (e.relatedTarget instanceof Node && touchControls.contains(e.relatedTarget))) {
          canvas.focus();
          return;
        }
        r.engine.pauseGame();
      };
    r.engine.onGameOver.add(toggleOverlay, changeToReplayButton);
    r.engine.onGamePaused.add(toggleOverlay);
    r.engine.onGameResumed.add(toggleOverlay);
    canvasShell.onclick = shellClicked;
    canvas.addEventListener("blur", triggerPause);

    lastEngineStats = r.engine.renderStats();
    canvas.insertAdjacentElement("afterend", lastEngineStats);
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    r.initGame().then(() => {
      toggleOverlay();
      r.draw({ engine: r.engine });
    }).catch((error) => {
      console.error("Failed to load game assets:", error);
    });
  }
  initialize(state.defaults);
}

if (document.readyState !== "loading") rootInit();
else document.addEventListener("load", rootInit);
