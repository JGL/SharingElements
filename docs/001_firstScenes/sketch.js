// Based on examples from: http://brm.io/matter-js/
// Originally from https://github.com/shiffman/p5-matter/blob/master/01_basics/sketch.js

// var Engine = Matter.Engine;
// var Render = Matter.Render;
// var World = Matter.World;
// var Body = Matter.Body;
// var Bodies = Matter.Bodies;
// var Composite = Matter.Composite;
// var Composites = Matter.Composites;
// var Constraint = Matter.Constraint;

// //via https://github.com/shiffman/p5-matter/blob/master/03_chain/sketch.js
// var Mouse = Matter.Mouse;
// var MouseConstraint = Matter.MouseConstraint;
// var mouseConstraint;

// var engine; //matter physics engine
// var world; //matter physics world
// var bodies; //matter physics bodies

// var ground; //ground object for the physics simluation, so that the rectangles can't go off the canvas
// var leftWall; //left wall as above
// var rightWall; //right wall as above
// var ceiling; //ceilling as above

// GUI controls: https://github.com/bitcraftlab/p5.gui
var visible; //is the GUI visible or not?
var gui; //the gui object itself

var manager;

let bodyImage;
let worldImage;
let gridImage;
let streamImage;

var centre = new p5.Vector();

function preload() {
  // preload() runs once
  bodyImage = loadImage("../img/scene_01.png");
  worldImage = loadImage("../img/scene_02.png");
  gridImage = loadImage("../img/scene_03.png");
  streamImage = loadImage("../img/scene_04.png");
}

function windowResized() {
  resizeCanvas(windowWidth, windowHeight);
  centre.set(width / 2, height / 2);
}

function setup() {
  //setting up colour mode and fill mode
  colorMode(HSB); //https://p5js.org/reference/#/p5/colorMode have to do it right at the start of setup, otherwise other created colours remember the colour mode they were created in
  //colorMode(HSB, 360, 100, 100, 1) is default

  //https://stackoverflow.com/questions/37083287/how-to-set-canvas-width-height-using-parent-divs-attributes
  //https://github.com/processing/p5.js/wiki/Beyond-the-canvas
  //https://github.com/processing/p5.js/wiki/Positioning-your-canvas

  createCanvas(windowWidth, windowHeight);
  centre.set(width / 2, height / 2);
  //console.log(canvas);
  //   canvas.parent("BodyElements"); //https://github.com/processing/p5.js/wiki/Beyond-the-canvas

  textSize(42); //42 is the answer to everything
  textAlign(CENTER, CENTER); //https://p5js.org/reference/#/p5/textAlign

  //   // create an engine
  //   engine = Engine.create();
  //   world = engine.world;

  //   // get mouse interaction set up....
  //   var mouse = Mouse.create(canvas.elt);
  //   var mouseParams = {
  //     mouse: mouse,
  //     constraint: {
  //       stiffness: 0.1,
  //     },
  //   };
  //   mouseConstraint = MouseConstraint.create(engine, mouseParams);
  //   mouseConstraint.mouse.pixelRatio = pixelDensity();
  //   World.add(world, mouseConstraint);

  //   //make walls to constrain everything
  //   var params = {
  //     isStatic: true,
  //   };
  //   ground = Bodies.rectangle(width / 2, height + 1, width, 1, params); //+1 so it's just below the bottom of the screen, Matter.Bodies.rectangle(x, y, width, height, [options])
  //   leftWall = Bodies.rectangle(0, height / 2, 1, height, params);
  //   rightWall = Bodies.rectangle(width, height / 2, 1, height, params);
  //   ceiling = Bodies.rectangle(width / 2, 0, width, 1, params);
  //   World.add(world, ground);
  //   World.add(world, leftWall);
  //   World.add(world, rightWall);
  //   World.add(world, ceiling);

  //   // run the engine
  //   Engine.run(engine);

  // Create Layout GUI
  visible = true;
  gui = createGui("Press g to hide/show me");

  manager = new SceneManager();

  // Preload scenes. Preloading is normally optional
  // ... but needed if showNextScene() is used.
  manager.addScene(BodyScene);
  manager.addScene(WorldScene);
  manager.addScene(GridScene);
  manager.addScene(StreamScene);

  manager.showNextScene();
}

// Using p5 to render
function draw() {
  background("red");
  //   clear(); //https://p5js.org/reference/#/p5/clear
  manager.draw();
}

function mousePressed() {
  manager.handleEvent("mousePressed");
}

// check for keyboard events
function keyPressed() {
  switch (key) {
    // type [g] to hide / show the GUI
    case "g":
      visible = !visible;
      if (visible) gui.show();
      else gui.hide();
      break;
    case "1":
      manager.showScene(BodyScene);
      console.log("Switching to BodyScene");
      break;
    case "2":
      manager.showScene(WorldScene);
      console.log("Switching to WorldScene");
      break;
    case "3":
      manager.showScene(GridScene);
      console.log("Switching to GridScene");
      break;
    case "4":
      manager.showScene(StreamScene);
      console.log("Switching to StreamScene");
      break;
  }

  // ... then dispatch via the SceneManager.
  manager.handleEvent("keyPressed");
}

// =============================================================
// =                         BEGIN SCENES                      =
// =============================================================

function BodyScene() {
  // enter() will be executed each time the SceneManager switches
  // to this animation
  this.enter = function () {};

  this.draw = function () {
    background("green");

    image(bodyImage, 0, 0, 300, 300); //TODO: change this to native size, and the others

    fill("black");
    text(
      "Press keys 1, 2, 3, 4 to jump to a particular scene\n" +
        "... or mouse to advance animation.\n\n" +
        "Press any other key to display it.",
      width / 2,
      height / 2
    );
  };

  this.mousePressed = function () {
    this.sceneManager.showNextScene();
  };
}

function WorldScene() {
  // enter() will be executed each time the SceneManager switches
  // to this animation
  this.enter = function () {};

  this.draw = function () {
    background("blue");
    image(worldImage, 0, 0, 300, 300); //TODO: change this to native size, and the others
    fill("black");
    text(
      "Press keys 1, 2, 3, 4 to jump to a particular scene\n" +
        "... or mouse to advance to next scene.\n\n" +
        width / 2,
      height / 2
    );
  };

  this.mousePressed = function () {
    this.sceneManager.showNextScene();
  };
}

function GridScene() {
  // enter() will be executed each time the SceneManager switches
  // to this animation
  this.enter = function () {};

  this.draw = function () {
    background("orange");
    image(gridImage, 0, 0, 300, 300); //TODO: change this to native size, and the others
    fill("black");
    text(
      "Press keys 1, 2, 3, 4 to jump to a particular scene\n" +
        "... or mouse to advance to next scene.\n\n" +
        width / 2,
      height / 2
    );
  };

  this.mousePressed = function () {
    this.sceneManager.showNextScene();
  };
}

function StreamScene() {
  // enter() will be executed each time the SceneManager switches
  // to this animation
  this.enter = function () {};

  this.draw = function () {
    background("pink");
    image(streamImage, 0, 0, 300, 300); //TODO: change this to native size, and the others
    fill("black");
    text(
      "Press keys 1, 2, 3, 4 to jump to a particular scene\n" +
        "... or mouse to advance to next scene.\n\n" +
        width / 2,
      height / 2
    );
  };

  this.mousePressed = function () {
    this.sceneManager.showNextScene();
  };
}
