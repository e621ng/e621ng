import { EngineConfig, SnakeRenderer, html } from "./snake_game";
import LStorage from "./utility/storage";

function rootInit () {
  // Escape hatch for people who hate fun.
  if (!LStorage.Site.Events) return;

  // Turn on the snake game on midnight of April 1st (Arizona time), turn it off at next midnight.
  const now = new Date(new Date().toLocaleString("en-US", {timeZone: "America/Phoenix"}));
  const isAprilFools = now.getMonth() === 3 && now.getDate() === 1;
  const hasStaffBypass = LStorage.get("e6.eventsBypass") === "true";
  if (!isAprilFools && !hasStaffBypass) return;

  // Notify people about the theme
  if (!/^\/?$/.test(window.location.pathname)) {
    if (localStorage.getItem("e6.latestTheme") !== "snake") {
      if (/^\/static\/theme\/?$/.test(window.location.pathname)) {
        localStorage.setItem("e6.latestTheme", "snake");
      } else {
        document.querySelector("#nav-themes").className += " notification";
      }
    }
  }

  const touchControls = html`
  <div id="touch-container">
    <span id="up"><i>▲</i></span>
    <span id="right"><i>▶</i></span>
    <span id="left"><i>◀</i></span>
    <span id="down"><i>▼</i></span>
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
 ::::::::  ::::    ::: :::::::::: :::    ::: 
:+:    :+: :+:+:   :+: :+:        :+:   :+:  
+:+        :+:+:+  +:+ +:+        +:+  +:+   
+#++:++#++ +#+ +:+ +#+ +#++:++#   +#++:++    
       +#+ +#+  +#+#+# +#+        +#+  +#+   
#+#    #+# #+#   #+#+# #+#        #+#   #+#  
 ########  ###    #### ########## ###    ### 
      </pre>
      ${canvasShell}
      ${touchControls}
      ${state.form}
    </div>
  </div>
  `;
  document.body.appendChild(container);

  /** @type {HTMLElement} **/ let lastEngineStats;
  let keydownShellToggle;
  let shouldAutoStartNextGame = false;
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
          shouldAutoStartNextGame = true;
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
    if (keydownShellToggle)
      canvas.removeEventListener("keydown", keydownShellToggle);
    keydownShellToggle = (e) => {
      if (e.key.toLowerCase() !== " ")
        return;
      e.preventDefault();
      shellClicked();
    };
    canvas.addEventListener("keydown", keydownShellToggle);
    canvas.addEventListener("blur", triggerPause);

    lastEngineStats = r.engine.renderStats();
    canvas.insertAdjacentElement("afterend", lastEngineStats);
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    r.initGame().then(() => {
      if (shouldAutoStartNextGame) {
        shouldAutoStartNextGame = false;
        hasStarted = true;
        r.startGame();
        canvas.focus();
      }
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
