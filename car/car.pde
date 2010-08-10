// Global variables
float wheelOffsetX;
float wheelOffsetY;
float X, Y;
float nX, nY;
boolean bover = false;
float sWidth, sHeight;

//Car Components
Chassis chassis;
SteeringControlAlg steeringControlAlg;
ThrottleControlAlg throttleControlAlg;
DriveModeAlg driveModeAlg;
Wheel wheelFL;
Wheel wheelFR;
Wheel wheelRR;
Wheel wheelRL;
WheelECU wheelECUFL;
WheelECU wheelECUFR;
WheelECU wheelECURR;
WheelECU wheelECURL;


//Enumerate Driving Modes
int normalMode = 0;
int hurricaneMode = 1;
int foldingMode = 2; //Disables driving while in the process of folding
int unfoldingMode = 3; //Disables driving while in the process of folding

//Colors
int bgColor = 124;


boolean messageMode;




//GENERAL TODOs:
/* Steering algorithm looks sketchy on right side - wtf?
 */



///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////// ECUS ////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

/*
Drive Mode Algorithm ECU Class
 Determines active mode and sets the activeMode of the steering Alg.
 Singleton Pattern 
 */
class DriveModeAlg extends Node{
  String name;
  int currentMode;
  int lastMode;
  float steeringInput;
  DriveModeAlg(String name){
    super(name);
    this.name = name;

    this.currentMode = normalMode;
    this.lastMode = normalMode;
  }
  void run(){
    check_folded_status();
  }
  void check_folded_status(){
    if (currentMode == foldingMode && chassis.get_length() == chassis.foldedL){
      currentMode = lastMode;
    }
    if (currentMode == unfoldingMode && chassis.get_length() == chassis.unfoldedL){
      currentMode = lastMode;
    }
  } 

  void h_mode(){
    if (currentMode != foldingMode && currentMode != unfoldingMode){
      currentMode = hurricaneMode;
      print_message("Activate Hurricane Mode");
    }
  }
  void n_mode(){    
    if (currentMode != foldingMode && currentMode != unfoldingMode){
      currentMode = normalMode;
      print_message("Normal Hurricane Mode");
    }

  }
  /*Bring wheels straight, fold, put wheels back into mode they were in before folding began.
   Disable all inputs except unfold */
  void fold(){
    print_message("Activate Folding Mode");
    if (currentMode == foldingMode){
      //don't do anything
      return;
    }
    else if (currentMode == unfoldingMode){
      //don't change lastMode
    }
    else{
      //store the mode we were in before folding began
      lastMode = currentMode;
    }
    //set folding mode
    this.currentMode = foldingMode;
    check_folded_status(); //are we already folded?  
  }

  /*Bring wheels straight, fold, put wheels back into mode they were in before folding began.
   Disable all inputs except unfold */
  void unfold(){
    print_message("Activate Unfolding Mode");
    if (currentMode == unfoldingMode){
      //don't do anything
      return;
    }
    else if (currentMode == foldingMode){
      //don't change lastMode
    }
    else{
      //store the mode we were in before folding began
      lastMode = currentMode;
    }
    //set folding mode
    this.currentMode = unfoldingMode;
    check_folded_status(); //are we already unfolded?
  }
  int get_mode(){
    return this.currentMode;
  }
  String get_mode_string(){
   if (get_mode() == 0)
    return "Normal Mode"; 
   if (get_mode() == 1)
    return "Hurricane Mode";
   if (get_mode() == 2)
    return "Folding Mode";
   if (get_mode() == 3)
    return "Unfolding Mode";
  
  return "ERROR";  
  }  
}

/*
Throttle Control Algorithm ECU Class
 Singleton Pattern 
 */
class ThrottleControlAlg extends Node{
  String name;
  float throttleInput;
  ThrottleControlAlg(String name){
    super(name);
    this.name = name;
  }
  void process_input(float throttleInput){
    this.throttleInput = 1-(throttleInput/300); //between -1 and 1
  }
  
  
  
  void run(){
    int driveMode = driveModeAlg.get_mode();
        if (driveMode==normalMode){
           change_throttle(this.throttleInput,wheelECUFL,driveMode);
    change_throttle(this.throttleInput,wheelECUFR,driveMode);
    change_throttle(this.throttleInput,wheelECURR,driveMode);
    change_throttle(this.throttleInput,wheelECURL,driveMode);
    
    }
    else if (driveMode == hurricaneMode){
      float scalar = .75;//reduce the throttle power by some scalar
    change_throttle(-this.throttleInput*scalar,wheelECUFL,driveMode);
    change_throttle(this.throttleInput*scalar,wheelECUFR,driveMode);
    change_throttle(-this.throttleInput*scalar,wheelECURR,driveMode);
    change_throttle(this.throttleInput*scalar,wheelECURL,driveMode);
    }
    else{
       change_throttle(0,wheelECUFL,driveMode);
    change_throttle(0,wheelECUFR,driveMode);
    change_throttle(0,wheelECURR,driveMode);
    change_throttle(0,wheelECURL,driveMode);
    }
  }
    /*
  Determine desired throttle based on throttle input and drive mode
   */
  void change_throttle(float throttleInput, WheelECU wheelECU, int driveMode){
    Wheel wheel = wheelECU.wheel; //Get the wheel associated with the wheel ECU
    wheel.set_throttle(throttleInput);

  }
}

/*
Steering Control Algorithm ECU Class
 Singleton Pattern 
 */
class SteeringControlAlg extends Node{
  String name;
  float steeringInput;
  SteeringControlAlg(String name){
    super(name);
    this.name = name;
  }

  void process_input(float steeringInput){
    this.steeringInput = steeringInput;
    if (driveModeAlg.get_mode() == foldingMode || driveModeAlg.get_mode() == unfoldingMode){
      //set all wheels to straight forwards
      this.steeringInput = width/2; //set wheels straight
    }
  }


  void run(){
    int driveMode = driveModeAlg.get_mode();
    print_message("Current Mode is: "+driveModeAlg.get_mode_string());
    change_steering(this.steeringInput,wheelECUFL,driveMode);
    change_steering(this.steeringInput,wheelECUFR,driveMode);
    change_steering(this.steeringInput,wheelECURR,driveMode);
    change_steering(this.steeringInput,wheelECURL,driveMode);
  }



  //calculate the turn radius based on the current steeringInput
  float get_turn_radius(){
    float trOffset=0, trCenterX=0, trCenterY=0;
    if(driveModeAlg.get_mode() == normalMode){
      //calculate desired turn radius
      trOffset = turn_radius((this.steeringInput*2/width)-1);
      trCenterX = trOffset;
      trCenterY = chassis.carCenterY;
    }
    else if(driveModeAlg.get_mode() == hurricaneMode){
      trCenterX = 0; //hack to put it in the right place
      trCenterY = chassis.carCenterY;
    } 
    else if(driveModeAlg.get_mode() == foldingMode || driveModeAlg.get_mode() == unfoldingMode){
      //calculate desired turn radius
      trOffset = turn_radius((this.steeringInput*2/width)-1);
      trCenterX = trOffset;
      trCenterY = chassis.carCenterY;
    }
    return trCenterX;

  }

  /*
  Determine desired angle based on steering input and drive mode
   */
  void change_steering(float steeringInput, WheelECU wheelECU, int driveMode){
    Wheel wheel = wheelECU.wheel; //Get the wheel associated with the wheel ECU

    if (driveMode==hurricaneMode){

      float yOff = chassis.carCenterY-wheel.wheelCenterY;
      float xOff = chassis.carCenterX-wheel.wheelCenterX;

      float angle = PI/2-atan(xOff/yOff);

      //hack to keep it pointing forward
      if(angle>(PI/2)){
        angle = angle-PI;
      }
      //Send message with angle  
      wheelECU.set_angle(angle);
    }
    else{
      float trOffset = this.turn_radius((this.steeringInput*2/width)-1);
      float trCenterX = trOffset;
      //  trCenterX = turn_radius(X)
      float trCenterY = chassis.carCenterY;

      float yOff = chassis.carCenterY-wheel.wheelCenterY;
      float xOff = abs(wheel.wheelCenterX-chassis.carCenterX) + trCenterX;
      float angle = PI/2-atan(xOff/yOff);

      //hack to keep it pointing forward
      if(angle>(PI/2)){
        angle = angle-PI;
      }
      //Send message with angle  
      wheelECU.set_angle(angle);
    }

  }

  // takes an input between -1 and 1, calculates turn radius.
  // we let the minimum turn radius be 100px and the max be 10^12
  float turn_radius(float normSteeringInput){ 
    if(normSteeringInput<0){
      //make positive, change scale, then make result negative
      return -this.turn_function(-normSteeringInput);
    }
    else{
      return this.turn_function(normSteeringInput);
    }
  }
  //maps [0,1] to [10^5,10^2]
  float turn_function(float val){
    float sensitivity_base = 10;
    float sensitivity_scalar = 3;
    float offset = 2.3; //how tight is the closest turn radius?

    //map [0,1] to [5,2]
    val=offset+sensitivity_scalar-(val*sensitivity_scalar);
    //use as exponent
    val = pow(sensitivity_base,val);
    return val;
  }

  // Draws turn radii that show the turning range of the car
  void draw_turn_radii(){

    float carCenterX = chassis.carCenterX;
    float carCenterY = chassis.carCenterY;
    float wheelOffsetX = chassis.wheelOffsetX;
    float wheelOffsetY = chassis.wheelOffsetY;
    float TR = steeringControlAlg.get_turn_radius();
    //draw turn left and right radius based on calulated trCenter
    // Draw inner turn radius
    // Set stroke-color  to grey 
    stroke(40);
    strokeWeight( 10 );  
    // Set fill-color to clear
    fill(0,0,0,0);


    if(driveModeAlg.get_mode() == hurricaneMode){
      float wheelRadius= sqrt(pow(wheelOffsetX,2) +pow(wheelOffsetY,2))+10;
      ellipse(carCenterX,carCenterY, wheelRadius*2,wheelRadius*2);  
    }
    else{
      float leftTR = sqrt(pow((TR+wheelOffsetX),2) +pow(wheelOffsetY,2));
      ellipse(TR+carCenterX, carCenterY, leftTR*2, leftTR*2);  
      float rightTR = sqrt(pow((TR-wheelOffsetX),2) +pow(wheelOffsetY,2));
      ellipse(TR+carCenterX, carCenterY, rightTR*2, rightTR*2);  
    }
  }
}

/*
Wheel Robot Class
 */
class WheelECU extends Node{
  float desiredAngle;
  Wheel wheel;
  String name;  
  WheelECU(String name,Wheel wheel){
    super(name);
    this.wheel = wheel;
    this.name = name;
  }
  /*
  Sets the desired angle, motor controller should take care of the rest.
   */
  void set_angle(float angle){
    //we print this in degrees rather than radians for clarity
    this.print_message("Change Desired Angle: "+str(angle*180/PI));
    this.desiredAngle = angle;

    //update steering MCU and receive updated position from it.
    wheel.set_angle(this.desiredAngle);
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////Flex Ray//////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////


/*
FlexRay Bus Class
 Messages are sent over the Flexray network, all the nodes on the FlexRay bus receive all
 the messages and write them to their FlexRay buffer. The Bus keeps track of all the nodes on it.
 */
class Bus extends NamedObject{
  ArrayList nodes;
  Bus(String name, ArrayList nodes){
    super(name);
    this.nodes = nodes;
  }
  void write(Message message){
    for (int i = nodes.size()-1; i >= 0; i--) { 
      //ArrayList doesn't know what it's storing so we have to cast it
      Node node = (Node) nodes.get(i);
      node.to_buffer(message);
      print_message(message+"");
    }
  }
}
/*
FlexRay Message Class
 Messages are sent over the Flexray network
 
 */
class Message {
  Node fromNode;
  Node toNode;
  String command;
  float argument;

  Message(Node FromNode, Node toNode, String command, float argument){
    this.fromNode = fromNode;
    this.toNode = toNode;
    this.command = command;
    this.argument = argument;
  }
}
/*
FlexRay Node Class
 Everything connected to the FlexRay bus with a FlexRay tranceiver is a FlexRay Node.
 */
class Node extends NamedObject {
  ArrayList buffer;
  Node(String name){
    super(name);
    buffer = new ArrayList(); //set up an empty arraylist
  }
  void to_buffer(Message message){
    buffer.add(message);
  }

  void read_buffer(){
    //read from front to back. Acts like a queue.
    for (int i = buffer.size()-1; i >= 0; i--) { 
      //ArrayList doesn't know what it's storing so we have to cast it
      Message message = (Message) buffer.get(i);
      //figure out what to do with the message.
      this.process(message);
    }
  }
  /* For now, just print the message instead of processing it.
   */
  void process(Message message){
    print_message(message+"");
  }

}


///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////Wheels (and MCU abstracted out)//////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

class Wheel extends NamedObject{
  float wheelCenterX; 
  float wheelCenterY;
  float currentAngle;
  float currentThrottle; //between -1 and 1
  float maxSteeringSpeed = .1;//PI/180*5; //we can turn at 5 degrees per frame  
  Wheel(String name, float centerX, float centerY){
    super(name);//create the parent
    this.wheelCenterX = centerX;
    this.wheelCenterY = centerY;
    this.currentAngle = 0; //TODO is this sensible?
    this.currentThrottle = 0;
  }
  void update_folded_position(float centerY){
    this.wheelCenterY = centerY; 
  }
  /*
  Send desired angle to MotorController and receive actual angle back
   */
  void set_angle(float desiredAngle){
    //figure out new current angle
    float angleDiff = this.currentAngle - desiredAngle;
    if(abs(angleDiff)<=maxSteeringSpeed){
      this.currentAngle = desiredAngle;
    }
    else if(angleDiff>maxSteeringSpeed){
      this.currentAngle = this.currentAngle-maxSteeringSpeed;

    }
    else if(angleDiff<-maxSteeringSpeed){
      this.currentAngle = this.currentAngle+maxSteeringSpeed;

    }
  }
  void draw(){
    pushMatrix();
    fill( 0);
    set_throttle_color();
    strokeWeight( 10 );  
    translate(wheelCenterX,wheelCenterY);
    rotate(this.currentAngle);
    ellipse(0,0,30,70);
    popMatrix();
  }
  void set_throttle_color(){
    //    stroke( 0, 121, 184 ); default
//       stroke( 255*abs(currentThrottle), 121+(255-121)*currentThrottle, 184+71*currentThrottle );
  stroke( 255*max(currentThrottle,0), 121+(255-121)*currentThrottle, 184*(currentThrottle+1));
  }

  float get_current_angle(){
    return this.currentAngle;
  }
  void set_throttle(float throttle){
   currentThrottle = throttle;
    this.print_message("Change Throttle: "+str(throttle*100)+" percent of max.");
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////// Chassis and Sensors ///////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

class Chassis {
  float chassisL;
  float chassisW;
  float wheelOffsetX;
  float wheelOffsetY;
  float carCenterX;
  float carCenterY;
  float foldedL = 130;
  float unfoldedL = 180;

  Chassis(){ 


    chassisL = 180;
    chassisW = 150;
    wheelOffsetX =chassisW/2-20;
    wheelOffsetY =chassisL/2-25;
    carCenterX =sWidth/2;
    carCenterY =sHeight/2;

    //Set up the car
    wheelFL = new Wheel("Front Left MCU",carCenterX-wheelOffsetX,carCenterY-wheelOffsetY);
    wheelFR = new Wheel("Front Right MCU",carCenterX+wheelOffsetX,carCenterY-wheelOffsetY);
    wheelRR = new Wheel("Rear Right MCU",carCenterX+wheelOffsetX,carCenterY+wheelOffsetY);
    wheelRL = new Wheel("Rear Left MCU",carCenterX-wheelOffsetX,carCenterY+wheelOffsetY);

    //set up the ECUs
    wheelECUFL = new WheelECU("Front Left ECU",wheelFL);
    wheelECUFR = new WheelECU("Front Right ECU",wheelFR);
    wheelECURR = new WheelECU("Rear Right ECU",wheelRR);
    wheelECURL = new WheelECU("Rear Left ECU",wheelRL);

  }

  void update_folded_size(){
    if ((driveModeAlg.get_mode() == foldingMode) && chassis.chassisL>130){
      chassisL-=2;
      wheelOffsetY =chassisL/2-25;
    }
    else if ((driveModeAlg.get_mode() == unfoldingMode) && chassisL<180){
      chassisL+=2;
      wheelOffsetY =chassisL/2-25;
    }
  }



  void run(){
    //folding stuff 
    if (((driveModeAlg.get_mode() == unfoldingMode) && chassis.chassisL<180) ||
      (driveModeAlg.get_mode() == foldingMode) && chassis.chassisL>130)  {  
      update_folded_size();
      wheelFL.update_folded_position(carCenterY-wheelOffsetY);
      wheelFR.update_folded_position(carCenterY-wheelOffsetY);
      wheelRR.update_folded_position(carCenterY+wheelOffsetY);
      wheelRL.update_folded_position(carCenterY+wheelOffsetY);
    }

  }

  void draw(){

    fill( 0, 200);
    stroke( 0, 121, 184, 255);
    strokeWeight( 10 );  
    //    ellipse( carCenterX,carCenterY,chassisW,chassisL);

    ellipse( carCenterX,carCenterY,chassisW,chassisL);
  }


  float get_length(){
    return this.chassisL;
  }

}


///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////DISPLAY UTILITIES - CONTROLS//////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

class NamedObject{
  String name;
  NamedObject(String name){
    this.name = name;
  }
  void print_message(String message){
    if (messageMode)
      println(name + ": " + message);
  }
}


void draw_controls(){
  float bh = 20;
  float bw = 85;
  float bx = 20;
  float by = 20;
  strokeWeight(1);    
  //modes  
  mode_box(normalMode,"Normal (n)",bx,by,bh,bw); 
  bx = 140;
  by = 20;
  mode_box(hurricaneMode,"O-Turn (h)",bx,by,bh,bw);   

  //folding  
  bx = 20;
  by = 50;
  fold_box(true,"Fold (f)",bx,by,bh,bw); 
  bx = 140;
  fold_box(false,"Unfold (u)",bx,by,bh,bw);  

  //messages
  by = 80;
  stroke(255);
  text("Messages (m):",20,by+bh-3);
  bw = 30;
  bx = 145;
  messages_box(true,"On",bx,by,bh,bw);
  bx = 195;
  by = 80;
  messages_box(false,"Off",bx,by,bh,bw);


}
void mode_box(int newDriveMode,String newDriveModeText, float bx,float by, float bh, float bw){
  int thisColor = 255;
  int contrastColor = 000;
  fill(thisColor);
  stroke(153);
  // if the cursor is over the grey box 
  if (mouseX > bx && mouseX < bx+bw && 
    mouseY > by && mouseY < by+bh) 
  {
    bover = true;  
    if(mousePressed) { 
      stroke(000); 
      fill(contrastColor);
      if (newDriveMode == hurricaneMode){
        driveModeAlg.h_mode();
      }
      else if (newDriveMode == normalMode){
        driveModeAlg.n_mode();
      }
    } 
    else {
      stroke(000);
      bover = false;
    }
  }
  // Draw the box
  rect(bx, by, bw, bh);
  fill(000);
  textSize(16);
  text(newDriveModeText,bx+3,by+bh-3);
}

void fold_box(boolean newFolded,String foldModeText, float bx,float by, float bh, float bw){
  int thisColor = 255;
  int contrastColor = 000;
  fill(thisColor);
  stroke(153);
  // if the cursor is over the grey box 
  if (mouseX > bx && mouseX < bx+bw && 
    mouseY > by && mouseY < by+bh) 
  {
    bover = true;  
    if(mousePressed) { 
      stroke(000); 
      fill(contrastColor);
      if(newFolded){
        driveModeAlg.fold();
      }
      else {
        driveModeAlg.unfold();
      }
    } 
    else {
      stroke(000);
      bover = false;
    }
  }
  // Draw the box
  rect(bx, by, bw, bh);
  fill(000);
  textSize(16);
  text(foldModeText,bx+3,by+bh-3);
}
void messages_box(boolean newMessageMode,String messageModeText, float bx,float by, float bh, float bw){
  int thisColor = 255;
  int contrastColor = 000;                
  fill(thisColor);
  stroke(153);
  // if the cursor is over the grey box 
  if (mouseX > bx && mouseX < bx+bw && 
    mouseY > by && mouseY < by+bh) 
  {
    bover = true;  
    if(mousePressed) { 
      stroke(000); 
      fill(contrastColor);
      messageMode = newMessageMode;
    } 
    else {
      stroke(000);
      bover = false;
    }
  }
  // Draw the box
  rect(bx, by, bw, bh);
  fill(000);
  textSize(16);
  text(messageModeText,bx+3,by+bh-3);
}

void keyPressed()
{
  // if the key is between 'A'(65) and 'z'(122)
  if( key == 'H' || key =='h' ) {
    driveModeAlg.h_mode();
  }
  else if( key == 'N' || key =='n' ) {
    driveModeAlg.n_mode();
  }  
  else if( key == 'M' || key =='m' ) {
    messageMode = !messageMode;
  }  
  else if( key == 'F' || key =='f' ) {
    driveModeAlg.fold();
  }
  else if( key == 'U' || key =='u' ) {
    driveModeAlg.unfold();
  }
}





///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////DISPLAY - SETUP AND DRAW////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////


void setup(){
  // Setup the Processing Canvas
  messageMode = false;
  chassis = new Chassis();
  steeringControlAlg = new SteeringControlAlg("Steering Control Alg");
  throttleControlAlg = new ThrottleControlAlg("Throttle Control Alg");
  driveModeAlg= new DriveModeAlg("Drive Mode Alg");  
  size( 1000, 600 );
  //for some reason width and height are buggy
  sWidth = 1000;
  sHeight = 600;
  strokeWeight( 10 );
  frameRate( 15 );
  X = width / 2;
  Y = height / 2;
  nX = X;
  nY = Y;  
}


// Main draw loop
void draw(){
  // Fill canvas grey
  background( 100 );

  //Read inputs from Joystick
  driveModeAlg.run();
  steeringControlAlg.process_input(X);
  throttleControlAlg.process_input(Y);
  steeringControlAlg.run();
  throttleControlAlg.run();

  chassis.run();

//  wheelFL.run();
//  wheelFR.run();
//  wheelRR.run();
//  wheelRL.run();

  pushMatrix();
  translate(width/2,height/2);
  steeringControlAlg.draw_turn_radii();


  // Draw wheels (clockwise)
  wheelFL.draw();
  wheelFR.draw();
  wheelRR.draw();
  wheelRL.draw();

  // Draw Car translucent
  chassis.draw();
  popMatrix();


  draw_controls();
}


// Set the input's next destination
void mouseMoved(){
  X = mouseX;
  Y = mouseY;  
}













