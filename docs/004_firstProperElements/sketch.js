// Based on examples from: http://brm.io/matter-js/
// Originally from https://github.com/shiffman/p5-matter/blob/master/01_basics/sketch.js
//https://github.com/liabru/matter-wrap
Matter.use("matter-wrap");
var Engine = Matter.Engine;
var Render = Matter.Render;
var World = Matter.World;
var Body = Matter.Body;
var Bodies = Matter.Bodies;
var Composite = Matter.Composite;
var Composites = Matter.Composites;
var Constraint = Matter.Constraint;

//via https://github.com/shiffman/p5-matter/blob/master/03_chain/sketch.js
var Mouse = Matter.Mouse;
var MouseConstraint = Matter.MouseConstraint;
var mouseConstraint;

var engine; //matter physics engine
var world; //matter physics world
var bodies; //matter physics bodies

var canvas;
var constraint;

var ground; //ground object for the physics simluation, so that the rectangles can't go off the canvas
var leftWall; //left wall as above
var rightWall; //right wall as above
var ceiling; //ceilling as above

var particles = []; //array holding all the particles/circles in the simulation
var numberOfParticles = 500;

// GUI controls: https://github.com/bitcraftlab/p5.gui
var visible; //is the GUI visible or not?
var gui; //the gui object itself

var manager;

let bodyImage;
let worldImage;
let gridImage;
let streamImage;

var centre = new p5.Vector();

let capture;
let poseNet;
let poses = [];
let captureWidth;
let captureHeight;
let horizontalRatioOfCaptureToCanvas;
let verticalRatioOfCaptureToCanvas;

//why does p5.gui need var not let?
var showCamera;
var showSkeleton;
var showKeypoints;
var mirrorVideo;
var trackingOpacity;
var trackingOpacityMin;
var trackingOpacityMax;
var trackingOpacityStep;

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
  horizontalRatioOfCaptureToCanvas = windowWidth / captureWidth;
  verticalRatioOfCaptureToCanvas = windowHeight / captureHeight;
}

function modelReady() {
  console.log("PoseNet Model Loaded");
}

function setup() {
  //setting up colour mode and fill mode
  colorMode(HSB); //https://p5js.org/reference/#/p5/colorMode have to do it right at the start of setup, otherwise other created colours remember the colour mode they were created in
  //colorMode(HSB, 360, 100, 100, 1) is default

  //https://stackoverflow.com/questions/37083287/how-to-set-canvas-width-height-using-parent-divs-attributes
  //https://github.com/processing/p5.js/wiki/Beyond-the-canvas
  //https://github.com/processing/p5.js/wiki/Positioning-your-canvas

  canvas = createCanvas(windowWidth, windowHeight);
  centre.set(width / 2, height / 2);
  //console.log(canvas);
  //   canvas.parent("BodyElements"); //https://github.com/processing/p5.js/wiki/Beyond-the-canvas

  textSize(42); //42 is the answer to everything
  textAlign(CENTER, CENTER); //https://p5js.org/reference/#/p5/textAlign

  // create an engine
  engine = Engine.create();
  world = engine.world;
  //zero gravity in matter.js
  //https://stackoverflow.com/questions/29466684/disabling-gravity-in-matter-js
  //https: //brm.io/matter-js/docs/classes/World.html#property_gravity
  world.gravity.y = 0;

  // get mouse interaction set up....
  var mouse = Mouse.create(canvas.elt);
  var mouseParams = {
    mouse: mouse,
    constraint: {
      stiffness: 0.1,
    },
  };
  mouseConstraint = MouseConstraint.create(engine, mouseParams);
  mouseConstraint.mouse.pixelRatio = pixelDensity();
  World.add(world, mouseConstraint);

  //now create and add the particles to the world
  for (var i = 0; i < numberOfParticles; i++) {
    var particleXPosition = random(width);
    var particleYPosition = random(height);
    var particleRadius = 8;

    //https://brm.io/matter-js/docs/classes/Bodies.html
    var aMatterCircle = Bodies.circle(
      particleXPosition,
      particleYPosition,
      particleRadius,
      {
        // friction: 0,
        // frictionAir: 0,

        // set the body's wrapping bounds
        plugin: {
          wrap: {
            min: {
              x: 0,
              y: 0,
            },
            max: {
              x: windowWidth,
              y: windowHeight,
            },
          },
        },
      }
    );

    var theParticleToRemember = new BodyElementsParticle(
      aMatterCircle,
      particleRadius
    );

    particles.push(theParticleToRemember);
    World.add(world, aMatterCircle);

    //set a random velocity of the new rectangle
    //see http://brm.io/matter-js/docs/classes/Body.html
    //from http://codepen.io/lilgreenland/pen/jrMvaB?editors=0010#0
    Body.setVelocity(aMatterCircle, {
      x: random(-1, 1),
      y: random(-1, 1),
    });
  }

  // run the engine
  Matter.Runner.run(engine);

  //set up default values for GUI variables
  showCamera = true;
  showSkeleton = true;
  showKeypoints = true;
  mirrorVideo = true;
  trackingOpacity = 0.5;
  trackingOpacityMin = 0.0;
  trackingOpacityMax = 1.0;
  trackingOpacityStep = 0.01;

  // Create Layout GUI
  visible = true;
  gui = createGui("Press g to hide/show me");
  gui.addGlobals(
    "showCamera",
    "showSkeleton",
    "showKeypoints",
    "mirrorVideo",
    "trackingOpacity"
  );

  manager = new SceneManager();

  // Preload scenes. Preloading is normally optional
  // ... but needed if showNextScene() is used.
  manager.addScene(BodyScene);
  manager.addScene(WorldScene);
  manager.addScene(GridScene);
  manager.addScene(StreamScene);

  manager.showNextScene();

  //create video and start posenet
  //duplicated from https://editor.p5js.org/ml5/sketches/PoseNet_webcam
  captureWidth = 320;
  captureHeight = 240;

  capture = createCapture(VIDEO);
  capture.size(captureWidth, captureHeight);

  // Create a new poseNet method with a single detection
  poseNet = ml5.poseNet(capture, modelReady);
  // This sets up an event that fills the global variable "poses"
  // with an array every time new poses are detected
  poseNet.on("pose", function (results) {
    poses = results;
  });
  // Hide the capture element, and just show the canvas
  capture.hide();

  //https://github.com/CodingTrain/website/blob/master/Q_and_A/Q_6_p5_background/sketch.js
  horizontalRatioOfCaptureToCanvas = windowWidth / captureWidth;
  verticalRatioOfCaptureToCanvas = windowHeight / captureHeight;
}

// Using p5 to render
function draw() {
  background("red");
  //   clear(); //https://p5js.org/reference/#/p5/clear
  textSize(42); //42 is the answer to everything
  manager.draw();

  let trackingColour = color(0, 0, 100, trackingOpacity); //white in HSB

  if (showCamera) {
    if (mirrorVideo) {
      //https://forum.processing.org/two/discussion/22546/how-do-i-flip-video-in-canvas-horizontally-in-p5js
      push();
      translate(width, 0); // move to far corner
      scale(-1.0, 1.0); // flip x-axis backwards
    }
    //https://p5js.org/reference/#/p5/tint
    tint(trackingColour);
    image(capture, 0, 0, width, height);
    if (mirrorVideo) {
      pop();
    }
  }

  if (showKeypoints) {
    if (mirrorVideo) {
      push();
      translate(width, 0); // move to far corner
      scale(-1.0, 1.0); // flip x-axis backwards
    }
    fill(trackingColour);
    drawKeypoints();
    if (mirrorVideo) {
      pop();
    }
  }

  if (showSkeleton) {
    if (mirrorVideo) {
      push();
      translate(width, 0); // move to far corner
      scale(-1.0, 1.0); // flip x-axis backwards
    }
    stroke(trackingColour);
    drawSkeleton();
    if (mirrorVideo) {
      pop();
    }
  }

  //draw the particle simluation here for now
  noStroke();
  textSize(8); //42 is the answer to everything
  //drawing the particles themselves
  for (var i = 0; i < particles.length; i++) {
    // Getting vertices of each object
    var theCircle = particles[i].matterCircle;
    var angle = theCircle.angle;
    var theColour = particles[i].colour;
    var translateTargetX = theCircle.position.x;
    var translateTargetY = theCircle.position.y;
    var theRadius = particles[i].particleRadius;

    fill(theColour);
    //p5.js takes diameter NOT radius
    //https://p5js.org/reference/#/p5/circle
    circle(translateTargetX, translateTargetY, theRadius * 2);

    fill(0);
    push();
    translate(translateTargetX, translateTargetY);
    rotate(angle);
    text(i, 0, 0);
    pop();
  }
}

function mousePressed() {
  // manager.handleEvent("mousePressed");
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

function BodyElementsParticle(theCircle, circleRadius) {
  // quick class to hold Matter Rectangle and its colour
  this.matterCircle = theCircle;
  this.colour = color(random(100), 100, 100, 100); //random hue, saturation 50%, brightness 100%, alpha 50%;
  this.particleRadius = circleRadius;
}

// A function to draw ellipses over the detected keypoints
function drawKeypoints() {
  // Loop through all the poses detected
  for (let i = 0; i < poses.length; i++) {
    // For each pose detected, loop through all the keypoints
    let pose = poses[i].pose;
    for (let j = 0; j < pose.keypoints.length; j++) {
      // A keypoint is an object describing a body part (like rightArm or leftShoulder)
      let keypoint = pose.keypoints[j];
      // Only draw an ellipse is the pose probability is bigger than 0.2
      if (keypoint.score > 0.2) {
        noStroke();
        ellipse(
          keypoint.position.x * horizontalRatioOfCaptureToCanvas,
          keypoint.position.y * verticalRatioOfCaptureToCanvas,
          10,
          10
        );
      }
    }
  }
}

// A function to draw the skeletons
function drawSkeleton() {
  // Loop through all the skeletons detected
  for (let i = 0; i < poses.length; i++) {
    let skeleton = poses[i].skeleton;
    // For every skeleton, loop through all body connections
    for (let j = 0; j < skeleton.length; j++) {
      let partA = skeleton[j][0];
      let partB = skeleton[j][1];
      line(
        partA.position.x * horizontalRatioOfCaptureToCanvas,
        partA.position.y * verticalRatioOfCaptureToCanvas,
        partB.position.x * horizontalRatioOfCaptureToCanvas,
        partB.position.y * verticalRatioOfCaptureToCanvas
      );
    }
  }
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
        // "... or mouse to advance animation.\n\n" +
        "\n\n Press any other key to display it.",
      width / 2,
      height / 2
    );
  };

  // this.mousePressed = function () {
  //   this.sceneManager.showNextScene();
  // };
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
    // this.sceneManager.showNextScene();
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
    // this.sceneManager.showNextScene();
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
    // this.sceneManager.showNextScene();
  };
}
