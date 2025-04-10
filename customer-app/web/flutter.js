// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/**
 * This script loads the Flutter web app.
 */
"use strict";

const flutterBaseUrl = new URL(document.currentScript.src).toString().replace(/flutter\.js$/, "");

/**
 * Creates a TrustedTypes policy that is used when creating the `flutter_service_worker.js` script.
 * @return {TrustedTypePolicy}
 */
function createTrustedTypesPolicy() {
  if (window.trustedTypes) {
    return trustedTypes.createPolicy("flutter-app", {
      createScriptURL: (url) => {
        if (url.startsWith(flutterBaseUrl)) {
          return url;
        }
        console.error(
          `Cannot load Flutter script from URL: ${url}. Only URLs starting with ${flutterBaseUrl} are allowed.`
        );
        return "";
      }
    });
  }
}

const flutterTrustedTypesPolicy = createTrustedTypesPolicy();

/**
 * Handles the browser-level event listeners that are needed for Flutter web apps.
 */
class BrowserEventHandler {
  /**
   * Adds a browser-level event listener for the given event.
   * @param {string} event
   * @param {function} handler
   */
  static addEventHandler(event, handler) {
    window.addEventListener(event, handler, false);
  }

  /**
   * Removes a browser-level event listener for the given event.
   * @param {string} event
   * @param {function} handler
   */
  static removeEventHandler(event, handler) {
    window.removeEventListener(event, handler, false);
  }
}

/**
 * Handles the Flutter web app's lifecycle.
 */
class FlutterLoader {
  /**
   * Creates a new FlutterLoader.
   */
  constructor() {
    // Initialize the loader state.
    this._didCreateEngineInitializer = false;
    this._didInitializeEngine = false;
    this._engineInitializer = null;
    this._autoStart = true;
  }

  /**
   * Loads the Flutter web app from the specified entrypoint.
   * @param {Object} options
   * @return {Promise}
   */
  loadEntrypoint(options) {
    const {
      entrypointUrl = "main.dart.js",
      serviceWorker,
      onEntrypointLoaded = (engineInitializer) => engineInitializer.initializeEngine().then((appRunner) => appRunner.runApp())
    } = options || {};

    return this._loadEntrypoint(entrypointUrl, serviceWorker, onEntrypointLoaded);
  }

  /**
   * Initializes the Flutter engine.
   * @return {Promise}
   */
  initializeEngine() {
    if (this._didInitializeEngine) {
      return Promise.resolve(this._appRunner);
    }
    return this._initialize();
  }

  /**
   * Runs the Flutter web app.
   * @return {Promise}
   */
  runApp() {
    return this._appRunner.runApp();
  }

  /**
   * Loads the Flutter web app from the specified entrypoint.
   * @param {string} entrypointUrl
   * @param {Object} serviceWorker
   * @param {function} onEntrypointLoaded
   * @return {Promise}
   */
  _loadEntrypoint(entrypointUrl, serviceWorker, onEntrypointLoaded) {
    if (!this._didCreateEngineInitializer) {
      this._didCreateEngineInitializer = true;
      this._createEngineInitializer();
    }

    if (serviceWorker) {
      const { serviceWorkerVersion, timeoutMillis = 4000 } = serviceWorker;
      this._serviceWorkerVersion = serviceWorkerVersion;
      this._serviceWorkerTimeoutMillis = timeoutMillis;
      this._loadServiceWorker();
    }

    return new Promise((resolve) => {
      this._scriptLoaded = () => {
        if (onEntrypointLoaded) {
          resolve(onEntrypointLoaded(this._engineInitializer));
        } else {
          resolve(this._engineInitializer);
        }
      };
      if (this._scriptLoaded) {
        BrowserEventHandler.removeEventHandler("load", this._scriptLoaded);
      }
      BrowserEventHandler.addEventHandler("load", this._scriptLoaded);
      
      // The loading of the script is handled by adding a script tag to the page.
      const scriptTag = document.createElement("script");
      scriptTag.src = entrypointUrl;
      scriptTag.type = "application/javascript";
      document.body.appendChild(scriptTag);
    });
  }

  /**
   * Creates the Flutter engine initializer.
   */
  _createEngineInitializer() {
    if (this._engineInitializer) {
      return;
    }

    // The Flutter engine initializer is a global object that is used to initialize the Flutter engine.
    this._engineInitializer = {
      /**
       * Initializes the Flutter engine.
       * @return {Promise}
       */
      initializeEngine: (config) => {
        if (this._didInitializeEngine) {
          return Promise.resolve(this._appRunner);
        }
        return this._initialize(config);
      },
      /**
       * Automatically starts the Flutter web app.
       * @param {boolean} auto
       */
      autoStart: (auto) => {
        this._autoStart = auto;
      }
    };
  }

  /**
   * Initializes the Flutter engine.
   * @param {Object} config
   * @return {Promise}
   */
  _initialize(config) {
    this._didInitializeEngine = true;

    // The Flutter app runner is a global object that is used to run the Flutter app.
    this._appRunner = {
      /**
       * Runs the Flutter web app.
       * @return {Promise}
       */
      runApp: () => Promise.resolve()
    };

    return Promise.resolve(this._appRunner);
  }

  /**
   * Loads the service worker.
   */
  _loadServiceWorker() {
    if ("serviceWorker" in navigator) {
      // Service workers are supported. Use them.
      window.addEventListener("load", () => {
        const serviceWorkerUrl = "flutter_service_worker.js?v=" + this._serviceWorkerVersion;
        // The service worker URL is created using the TrustedTypes policy.
        const serviceWorkerUrl2 = flutterTrustedTypesPolicy
          ? flutterTrustedTypesPolicy.createScriptURL(serviceWorkerUrl)
          : serviceWorkerUrl;
        navigator.serviceWorker.register(serviceWorkerUrl2).then((reg) => {
          function waitForActivation(serviceWorker) {
            serviceWorker.addEventListener("statechange", () => {
              if (serviceWorker.state == "activated") {
                console.log("Installed new service worker.");
                this._serviceWorkerActivated = true;
              }
            });
          }
          if (!reg.active && (reg.installing || reg.waiting)) {
            // No active web worker and we have installed or are installing
            // one for the first time. Simply wait for it to activate.
            waitForActivation(reg.installing || reg.waiting);
          } else if (!reg.active.scriptURL.endsWith(this._serviceWorkerVersion)) {
            // When the app updates the serviceWorkerVersion changes, so we
            // need to ask the service worker to update.
            console.log("New service worker available.");
            reg.update();
            waitForActivation(reg.installing);
          } else {
            // Existing service worker is still good.
            console.log("Loading app from service worker.");
            this._serviceWorkerActivated = true;
          }
        });

        // If service worker doesn't succeed in a reasonable amount of time,
        // fallback to plaint <script> tag.
        setTimeout(() => {
          if (!this._serviceWorkerActivated) {
            console.warn(
              "Failed to load app from service worker. Falling back to plain <script> tag."
            );
          }
        }, this._serviceWorkerTimeoutMillis);
      });
    } else {
      // Service workers not supported. Just drop the <script> tag.
      console.warn("Service workers are not supported.");
    }
  }
}

// This is the entry point for the Flutter web app.
window._flutter = new FlutterLoader();
