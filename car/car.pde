// Global variables
float wheelOffsetX;
float wheelOffsetY;
float X, Y;
float nX, nY;
float carCenterX, carCenterY;
boolean bover = false;
float chassisLength;
float chassisWidth;
ControlAlg controlAlg;

//Enumerate Modes
int normalMode = 0;
int hurricaneMode = 1;

//Colors
int bgColor = 124;


boolean messageMode;

//wheels are front,rear,left and right
Wheel wheelFL,wheelFR,wheelRR,wheelRL;









///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////// ECUS ////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

/*
Control Algorithm ECU Class
Singleton Pattern 
 */
class ControlAlg {

  int currentMode;
  Wheel wheelFL;
  Wheel wheelFR;
  Wheel wheelRR;
  Wheel wheelRL;
  boolean folded;
  ControlAlg(Wheel wheelFL,Wheel wheelFR,Wheel wheelRR,Wheel wheelRL){
    //The control algorithm is aware of which wheels are attached.
    this.wheelFL = wheelFL;
    this.wheelFR = wheelFR;
    this.wheelRR = wheelRR;
    this.wheelRL = wheelRL;

    this.currentMode = 0;
    this.folded = false;
  }

  void process_input(float X){
    change_steering(X,wheelFL);
    change_steering(X,wheelFR);
    change_steering(X,wheelRR);
    change_steering(X,wheelRL);
  }
  void h_mode(){
    currentMode = hurricaneMode;
  }
  void n_mode(){
    currentMode = normalMode;
  }

  float get_turn_radius(float X){
    float trOffset=0, trCenterX=0, trCenterY=0;
    if(controlAlg.currentMode == normalMode){
      //calculate desired turn radius
      trOffset = turn_radius((X*2/width)-1);
      trCenterX = trOffset;
      trCenterY = carCenterY;
    }
    else if(controlAlg.currentMode == hurricaneMode){
      trCenterX = 0; //hack to put it in the right place
      trCenterY = carCenterY;
    }
    return trCenterX;
  }

  /*
  Deter desired angle based on steering input and drive mode
   */
  void change_steering(float steeringInput, Wheel wheel){

    if(currentMode==normalMode){
      float trOffset = turn_radius((steeringInput*2/width)-1);
      float trCenterX = trOffset;
      //  trCenterX = turn_radius(X)
      float trCenterY = carCenterY;
      float yOff = carCenterY-wheel.wheelCenterY;
      float xOff = abs(wheel.wheelCenterX-carCenterX) + trCenterX;

      float angle = PI/2-atan(xOff/yOff);

      //hack to keep it pointing forward
      if(angle>(PI/2)){
        angle = angle-PI;
      }
      //Send message with angle  
      wheel.set_angle(angle);
    }
    else if (currentMode==hurricaneMode){

      float yOff = carCenterY-wheel.wheelCenterY;
      float xOff = carCenterX-wheel.wheelCenterX;

      float angle = PI/2-atan(xOff/yOff);

      //hack to keep it pointing forward
      if(angle>(PI/2)){
        angle = angle-PI;
      }
      //Send message with angle  
      wheel.set_angle(angle);
    }
  }

  // takes an input between -1 and 1, calculates turn radius.
  // we let the minimum turn radius be 100px and the max be 10^12
  float turn_radius(float steeringInput){ 
    if(steeringInput<0){
      //make positive, change scale, then make result negative
      return -turn_function(-steeringInput);
    }
    else{
      return turn_function(steeringInput);
    }
  }

}

/*
Wheel Robot ECU Class
 */
class Wheel {
  float wheelCenterX,wheelCenterY;
  float currentAngle,desiredAngle;
  String name;
  //float maxSteeringSpeed = PI/180*5; //we can turn at 5 degrees per frame
  float maxSteeringSpeed = .5;//PI/180*5; //we can turn at 5 degrees per frame    
  Wheel(String name, float centerX, float centerY){
    this.name = name;
    this.wheelCenterX = centerX;
    this.wheelCenterY = centerY;
  }

  void print_message(String message){
    if (messageMode)
      println(name + " received message:" + message);
  }

  void update_wheel_position(float centerY){
    this.wheelCenterY = centerY; 
  }

  /*
  Sets the desired angle, motor controller should take care of the rest.
   */
  void set_angle(float angle){
    //we print this in degrees rather than radians for clarity
    this.print_message(" change desired angle "+str(angle*180/PI));
    this.desiredAngle = angle;
  }
  /*
  Simulates the action of the motor controller and wheels
   */
  void draw(){
    pushMatrix();
    fill( 0);
    stroke( 0, 121, 184 );
    strokeWeight( 10 );  

    //figure out new current angle
    float angleDiff = this.currentAngle - this.desiredAngle;
    if(abs(angleDiff)<maxSteeringSpeed){
      this.currentAngle = this.desiredAngle;
    }
    else if(angleDiff>maxSteeringSpeed){
      this.currentAngle = this.currentAngle-maxSteeringSpeed;

    }
    else if(angleDiff<-maxSteeringSpeed){
      this.currentAngle = this.currentAngle+maxSteeringSpeed;
    }

    translate(wheelCenterX,wheelCenterY);
    rotate(this.currentAngle);
    ellipse(0,0,30,70);
    popMatrix();

  }
}













///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////SETUP AND DRAW//////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

void setup(){
  // Setup the Processing Canvas
  messageMode = false;
  chassisLength = 180;
  chassisWidth = 150;
  wheelOffsetX =chassisWidth/2-20;
  wheelOffsetY =chassisLength/2-25;
  size( 1000, 600 );
  strokeWeight( 10 );
  frameRate( 15 );
  X = width / 2;
  Y = height / 2;
  nX = X;
  nY = Y;  
  //Set up the car
  carCenterX = width/2;
  carCenterY = height/2;
  wheelFL = new Wheel("Front Left",carCenterX-wheelOffsetX,carCenterY-wheelOffsetY);
  wheelFR = new Wheel("Front Right",carCenterX+wheelOffsetX,carCenterY-wheelOffsetY);
  wheelRR = new Wheel("Rear Right",carCenterX+wheelOffsetX,carCenterY+wheelOffsetY);
  wheelRL = new Wheel("Rear Left",carCenterX-wheelOffsetX,carCenterY+wheelOffsetY);

  controlAlg = new ControlAlg(wheelFL,wheelFR,wheelRR,wheelRL);
}


// Main draw loop
void draw(){
  // Fill canvas grey
  background( 100 );

  //update folded/unfolded status
  if ((!controlAlg.folded && chassisLength<180) || (controlAlg.folded && chassisLength>130)){  
    update_folded();
    wheelFL.update_wheel_position(carCenterY-wheelOffsetY);
    wheelFR.update_wheel_position(carCenterY-wheelOffsetY);
    wheelRR.update_wheel_position(carCenterY+wheelOffsetY);
    wheelRL.update_wheel_position(carCenterY+wheelOffsetY);
  }

  float trCenterX = controlAlg.get_turn_radius(X);
  //draw turn left and right radius based on calulated trCenter
  draw_turn_radii(trCenterX);

  //update the desired position of each wheel
  if (messageMode)
    println("UPDATING WHEEL STEERING");
  controlAlg.process_input(X);
  // Draw wheels (clockwise)
  wheelFL.draw();
  wheelFR.draw();
  wheelRR.draw();
  wheelRL.draw();

  // Draw Car translucent

  //draw_turn_radius_center();
  draw_chassis();
  draw_controls();
}


// Set the input's next destination
void mouseMoved(){
  X = mouseX;
  Y = mouseY;  
}

///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////DISPLAY UTILITIES - CONTROLS//////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////


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
  fold_box(false,"Unfold (f)",bx,by,bh,bw);  

  //messages
  by = 80;
  stroke(255);
  text("Message Mode (m):",20,by+bh-3);
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
      controlAlg.currentMode = newDriveMode;
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
      controlAlg.folded = newFolded;
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
    controlAlg.h_mode();
  }
  else if( key == 'N' || key =='n' ) {
    controlAlg.n_mode();
  }  
  else if( key == 'F' || key =='f' ) {
    controlAlg.folded = !controlAlg.folded;
  }  
  else if( key == 'M' || key =='m' ) {
    messageMode = !messageMode;
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

///////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////DISPLAY UTILITIES - CAR///////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

void update_folded(){
  if (controlAlg.folded && chassisLength>130){
    chassisLength-=2;
    wheelOffsetY =chassisLength/2-25;
  }
  else if (!controlAlg.folded && chassisLength<180){
    chassisLength+=2;
    wheelOffsetY =chassisLength/2-25;
  }
}

// Draws turn radii that show the turning range of the car
void draw_turn_radii(float TR){
  // Draw inner turn radius
  // Set stroke-color  to grey 
  stroke(40);
  strokeWeight( 10 );  
  // Set fill-color to clear
  fill(0,0,0,0);

  if(controlAlg.currentMode == normalMode){
    float leftTR = sqrt(pow((TR+wheelOffsetX),2) +pow(wheelOffsetY,2));
    ellipse(TR+carCenterX, carCenterY, leftTR*2, leftTR*2);  
    float rightTR = sqrt(pow((TR-wheelOffsetX),2) +pow(wheelOffsetY,2));
    ellipse(TR+carCenterX, carCenterY, rightTR*2, rightTR*2);  
  }
  else if(controlAlg.currentMode == hurricaneMode){
    float wheelRadius= sqrt(pow(wheelOffsetX,2) +pow(wheelOffsetY,2))+10;
    ellipse(carCenterX,carCenterY, wheelRadius*2,wheelRadius*2);  
  }
}

void draw_chassis(){
  fill( 0, 200);
  stroke( 0, 121, 184, 255);
  strokeWeight( 10 );  
  ellipse( carCenterX,carCenterY,chassisWidth,chassisLength);
}




