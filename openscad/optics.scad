/******************************************************************
*                                                                 *
* OpenFlexure Microscope: Optics unit                             *
*                                                                 *
* This is part of the OpenFlexure microscope, an open-source      *
* microscope and 3-axis translation stage.  It gets really good   *
* precision over a ~10mm range, by using plastic flexure          *
* mechanisms.                                                     *
*                                                                 *
* The optics module holds the camera and whatever lens you are    *
* using as an objective - current options are either the lens     *
* from the Raspberry Pi camera module, or an RMS objective lens   *
* and a second "tube length conversion" lens (usually 40mm).      *
*                                                                 *
* See the section at the bottom of the file for different         *
* versions, to suit different combinations of optics/cameras.     *
* NB you set the camera in the variable at the top of the file.   *
*                                                                 *
* (c) Richard Bowman, January 2016                                *
* Released under the CERN Open Hardware License                   *
*                                                                 *
******************************************************************/

use <utilities.scad>;
use <cameras/picam_push_fit.scad>;
use <cameras/picam_2_push_fit.scad>;
use <cameras/C270_mount.scad>;
use <cameras/usbcam_push_fit.scad>;
use <dovetail.scad>;
include <microscope_parameters.scad>; // important for objective clip position, etc.

//camera = "C270"; // Mid-range Logitech webcam, relatively easy to dissassemble
//camera = "picamera"; // Raspberry Pi Camera module v1
camera = "picamera2"; // Raspberry Pi Camera module v2
//camera = "usbcam"; //A USB camera including LED, that we sourced from China

bottom = -8; //nominal distance from PCB to microscope bottom
dt_bottom = -2; //where the dovetail starts (<0 to allow some play)
fl_cube_bottom = 0; //bottom of the fluorescence filter cube
fl_cube_w = 16; //width of the fluorescence filter cube
fl_cube_top = fl_cube_bottom + fl_cube_w + 2.7; //top of fluorescence cube
fl_cube_top_w = fl_cube_w - 2.7;
d = 0.05;

// The camera parameters depend on what camera we're using,
// sorry about the ugly syntax, but I couldn't find a neater way.
camera_angle = (camera=="picamera"||camera=="picamera2"||camera=="usbcam"?45:
               (camera=="C270"?-45:0));
camera_h = (camera=="picamera"||camera=="picamera2"?24:
           (camera=="C270"?53:
           (camera=="usbcam"?40:0)));
camera_shift = (camera=="picamera"||camera=="picamera2"?2.4:
               (camera=="C270"?(45-53/2):
               (camera=="usbcam"?0:0)));

$fn=24;

module camera(){
    //This creates a cut-out for the camera we've selected
    if(camera=="picamera"){
        picam_push_fit();
    }else if(camera=="picamera2"){
        picam2_push_fit();
    }else if(camera=="C270"){
        C270(beam_r=5,beam_h=6+d);
    }else if(camera=="usbcam"){
        usbcam_push_fit();
    }
}

module fl_cube_cutout(taper=true){
    // A cut-out that enables a filter cube to be inserted.
    union(){
        sequential_hull(){
            translate([-fl_cube_w/2,-fl_cube_w/2,fl_cube_bottom]) cube([fl_cube_w,999,fl_cube_w]);
            translate([-fl_cube_w/2+2,-fl_cube_w/2,fl_cube_bottom]) cube([fl_cube_w-4,999,fl_cube_w+2]); //sloping sides
            translate([-fl_cube_w/2+2,-fl_cube_w/2+2,fl_cube_bottom]) cube([fl_cube_w-4,fl_cube_w-4,fl_cube_w+2]);
            if(taper) translate([-d,-d,fl_cube_bottom]) cube([2*d,2*d,fl_cube_w*1.5]); //taper gradually to the diameter of the beam
        }
        //a space at the back to allow the grippers for the dichroics to extend back a bit further.
        hull(){
            translate([-fl_cube_w/2+2,-fl_cube_w/2-1,fl_cube_bottom]) cube([fl_cube_w-4,999,fl_cube_w]);
            translate([-fl_cube_w/2+4,-fl_cube_w/2,fl_cube_bottom]) cube([fl_cube_w-8,999,fl_cube_w+2]);
        }
            
    }
}
module optical_path(lens_aperture_r, lens_z){
    // The cut-out part of a camera mount, consisting of
    // a feathered cylindrical beam path and a camera mount
    union(){
        rotate(camera_angle) translate([0,0,bottom]) camera();
        // //camera
        translate([0,0,bottom+6]) lighttrap_cylinder(r1=5, r2=lens_aperture_r, h=lens_z-bottom-6+d); //beam path
        translate([0,0,lens_z]) cylinder(r=lens_aperture_r,h=2*d); //lens
    }
}
module optical_path_fl(lens_aperture_r, lens_z){
    // The cut-out part of a camera mount, with a space to slot in a filter cube.
    union(){
        rotate(camera_angle) translate([0,0,bottom]) camera(); //camera
        translate([0,0,bottom+6]) lighttrap_sqylinder(r1=5, f1=0,
                r2=0, f2=fl_cube_w-4, h=fl_cube_bottom-bottom-6+d); //beam path to bottom of cube
        rotate(180) fl_cube_cutout(); //filter cube
        translate([0,0,fl_cube_top-d]) lighttrap_sqylinder(r1=1.5, f1=fl_cube_w-4-3, r2=lens_aperture_r, f2=0, h=lens_z-fl_cube_top+4*d); //beam path
        translate([0,0,lens_z]) cylinder(r=lens_aperture_r,h=2*d); //lens
    }
}
    
module lens_gripper(lens_r=10,h=6,lens_h=3.5,base_r=-1,t=0.65,solid=false){
    // This creates a tapering, distorted hollow cylinder suitable for
    // gripping a small cylindrical (or spherical) object
    // The gripping occurs lens_h above the base, and it flares out
    // again both above and below this.
    trylinder_gripper(inner_r=lens_r, h=h, grip_h=lens_h, base_r=base_r, t=t, solid=solid);
}

module chamfer_bottom_edge(chamfer=0.3, h=0.5){
    difference(){
        children();
        
        minkowski(){
            cylinder(r1=2*chamfer, r2=0, h=2*h, center=true);
            linear_extrude(d) difference(){
                square(9999, center=true);
                projection(cut=true) translate([0,0,-d]) hull() children();
            }
        }
    }
}
        
module fl_cube_outer(){
    // The outer body for fl_cube()
    roc = 0.6;
    w = fl_cube_w;
    foot = roc*0.7;
    bottom_t = roc*3;
    $fn=8;
    chamfer_bottom_edge() union(){
        reflect([1,0,0]){
            // outer "arms" that are responsible for the tight fit
            sequential_hull(){
                translate([w/2-2-roc*0.8/sqrt(2), w+2-roc*1.2, 0]) cylinder(r=roc, h=w);
                translate([w/2-roc, w-roc/sqrt(2), 0]) cylinder(r=roc, h=w);
                translate([w/2-roc, foot+bottom_t+roc, 0]) cylinder(r=roc, h=w);
            }
            translate([w/2-3*roc, foot+bottom_t+roc, 0]) difference(){
                // the curved bits at the bottom
                resize([0,(bottom_t+roc)*2,0]) cylinder(r=3*roc, h=w, $fn=24);
                // cut out the inner radius
                cylinder(r=roc, h=999, center=true);
                // restrict it to a quarter-turn
                mirror([1,0,0]) translate([-roc,0,-99]) cube(999);
                mirror([1,0,0]) translate([0,-roc,-99]) cube(999);
            }
        }
        // join the two arms together at the bottom
        translate([0,foot+bottom_t/2, w/2]) cube([w - roc*3*2 + 2*d, bottom_t, w], center=true);
        
        // feet at the bottom (and also in the middle of the top part)
        for(p = [[-w/2+roc*3, roc, roc+0.5], 
                 [w/2-roc*3, roc, roc+0.5], 
                 [0, roc, w-roc],
                 [w/2-2-roc*0.3/sqrt(2), w+2-roc*1.2, w/2],
                 [-(w/2-2-roc*0.3/sqrt(2)), w+2-roc*1.0, w/2]
                ]){
            translate(p) sphere(r=roc,$fn=8);
        }
    }
}
module fl_cube(){
    // Filter cube that slots into a suitably-modified optics module
    // This prints with the Y axis vertical - to save rotating all the
    // cylinders, it's written here as printed.
    roc = 0.6;
    w = fl_cube_w;
    foot = roc*0.7;
    bottom_t = roc*3;
    dichroic = [12,16,1.1];
    dichroic_t = dichroic[2];
    emission_filter = [10,14,1.5];
    beamsplit = [0, w/2+2, w/2];
    inner_w = w - 6*roc;
    bottom = bottom_t + foot;
    $fn=8;
    difference(){
        union(){
            fl_cube_outer();
            
            // mount for 45 degree dichroic, with bottom retaining clip
            by = beamsplit[1] + dichroic[1]/2/sqrt(2) + 0.3; //coated tip of dichroic + wiggle room
            bz = beamsplit[2] - dichroic[1]/2/sqrt(2) + 0.3; //coated tip of dichroic + wiggle room
            bby = beamsplit[1] + dichroic[1]/2/sqrt(2) - dichroic[2]/sqrt(2); //back tip of dichroic
            bbz = beamsplit[2] - dichroic[1]/2/sqrt(2) - dichroic[2]/sqrt(2); //back tip of dichroic
            sequential_hull(){
                translate([-inner_w/2, bottom, 0]) cube([inner_w, d, beamsplit[2] + beamsplit[1] - bottom - dichroic_t*sqrt(2)]); // tall back of triangle
                translate([-inner_w/2, bby, 0]) cube([inner_w, d, bbz]); //pointy end of triangle
                translate([-inner_w/2+2, by, 0]) cube([inner_w-4, 1.5, bz]); //far end
                translate([-inner_w/2+2, by, bz]) cube([inner_w-4, 1.5, d]); //start of retaining clip
                translate([-inner_w/2, by - 4, 4 + 2*dichroic_t]) cube([inner_w, 2, d]); //end of retaining clip
                translate([-inner_w/2, by - 5, 4 + 2*dichroic_t]) cube([inner_w, 2, 1]); //overhanging bit
            }
            
            // attachment for the excitation filter and LED
            reflect([1,0,0]) translate([-w/2, bottom + 4, w]) sequential_hull(){
                depth = w-bottom-4-roc;
                translate([0,0,-roc]) cube([2*roc, depth, d]); 
                translate([0.5,0,roc]) cube([2*roc, depth, 1.5]);
                translate([0.5+2*roc + 1.5 - 0.2*(1+sqrt(2)),0,roc+1.5-0.2]) rotate([-90,0,0]) cylinder(r=0.2, h=depth);//cube([2*roc + 1.5, depth, d]);
            }
        }
        // hole for the beam
        translate(beamsplit) rotate([90,0,0]) cylinder(r=5,h=999, center=true, $fn=32);
        // hole for the emission filter
        translate([-emission_filter[0]/2, bottom - roc*1.5, beamsplit[2]-emission_filter[1]/2]) cube([emission_filter[0], emission_filter[2], 999]);
        // access hole for the dichroic
        translate(beamsplit) rotate([-45,0,0]) translate([0,-dichroic[1]/2,0]) scale([1.1,1,1.9]) cube(dichroic, center=true);
    }
}

module fl_led_mount(){
    // This part clips on to the filter cube, to allow a light source (generally LED) to be coupled in using the beamsplitter.
    roc = 0.6;
    w = fl_cube_w - 1; //nominal width of the mount (is the width between the outsides of the dovetail clip points)
    dovetail_pinch = fl_cube_w - 4*roc - 1 - 3; //width between the pinch-points of the dovetail
    h = 10;
    filter = [10,14,1.5];
    beamsplit = [0, 0, w/2+2]; //NB different to fl_cube because we're printing with z=z here.
    $fn=8;
    led_y = beamsplit[2] - bottom; //place LED and camera in conjugate planes (nb this is the *camera* bottom, not fl_cube's redefinition)
    front_t = 6;
    front_y = led_y + front_t;
    back_y = fl_cube_w/2 + roc + 1.5; //flat of dovetail (we actually start 1.5mm behind this)
    union() translate([0,0,beamsplit[2]-h/2]){
        difference(){
            union(){
                translate([0, back_y, 0]) mirror([0,1,0]) dovetail_m([w, led_y - back_y - roc, h], t=2*roc);
                hull() reflect([1,0,0]) translate([w/2-3*roc, led_y - roc, 0]) resize([0,2*front_t,0]) 
                                                                cylinder(r=3*roc, h=h, $fn=16);
            }
            
            // cut out the middle of the dovetail so it's compressible
            cube([dovetail_pinch - 3, 2*(led_y-roc), 999], center=true); //cut out the centre to create arms
            translate([-w/2+2*roc, back_y+1.5, 0.5]) cube([w-4*roc, led_y-roc - back_y - 1.5, 999]);
            hull() reflect([1,0,0]) translate([w/2-3*roc, led_y - roc, 0.5]) cylinder(r=roc, h=999, $fn=16);
            
            // add a hole for the LED
            translate([0,led_y,h/2]){
                cylinder_with_45deg_top(h=999, r=3/2*1.05, $fn=16, extra_height=0, center=true); //LED
                translate([0,3,0]) cylinder_with_45deg_top(h=999, r=4/2*1.05, $fn=16, extra_height=0);
            }
        }
        
        difference(){
            translate([-(dovetail_pinch - 5)/2, back_y, 0]) cube([dovetail_pinch - 5, led_y - back_y + d, h]);
            translate([0,led_y,h/2]){
                translate([0,3,0]) cylinder_with_45deg_top(h=999, r=3.5/2*1.05, $fn=16, extra_height=0, center=true); //beam
            }
        }
    }
}

module camera_mount_body(
        body_r, //radius of mount body
        body_top, //height of the top of the body
        dt_top, //height of the top of the dovetail
        extra_rz = [], //extra [r,z] values to extend the mount
        bottom_r=8, //radius of the bottom of the mount
        fluorescence=false //whether to leave a port for fluorescence beamsplitter etc.
    ){
    // Make a camera mount, with a cylindrical body and a dovetail.
    // Just add a lens mount on top for a complete optics module!
    dt_h=dt_top-dt_bottom;
    union(){
        difference(){
            // This is the main body of the mount
            sequential_hull(){
                rotate(camera_angle) translate([0,camera_shift,bottom]) cube([25,camera_h,d],center=true);
                rotate(camera_angle) translate([0,camera_shift,bottom+1.5]) cube([25,camera_h,d],center=true);
                rotate(camera_angle) translate([0,camera_shift,bottom+4]) cube([25-5,camera_h,d],center=true);
                translate([0,0,dt_bottom]) hull(){
                    cylinder(r=bottom_r,h=d);
                    translate([0,objective_clip_y,0]){
                        cube([objective_clip_w+4,d,d],center=true);
                        cube([objective_clip_w,4,d],center=true);
                    }
                    if(fluorescence) cube([1,1,0]*(fl_cube_w+2) + [0,0,d], center=true);
                }
                translate([0,0,dt_bottom])hull(){
                    cylinder(r=bottom_r,h=d);
                    if(fluorescence) cube([1,1,0]*(fl_cube_w+2) + [0,0,d], center=true);
                }
                if(fluorescence) translate([0,0,fl_cube_bottom + fl_cube_w]){
                    cylinder(r=body_r,h=d);
                    if(fluorescence) cube([1,1,0]*(fl_cube_w+2) + [0,0,d], center=true);
                }
                translate([0,0,body_top]) cylinder(r=body_r,h=d);
                // allow for extra coordinates above this, if wanted.
                // this should really be done with a for loop, but
                // that breaks the sequential_hull, hence the kludge.
                if(len(extra_rz) > 0) translate([0,0,extra_rz[0][1]-d]) cylinder(r=extra_rz[0][0],h=d);
                if(len(extra_rz) > 1) translate([0,0,extra_rz[1][1]-d]) cylinder(r=extra_rz[1][0],h=d);
                if(len(extra_rz) > 2) translate([0,0,extra_rz[2][1]-d]) cylinder(r=extra_rz[2][0],h=d);
                if(len(extra_rz) > 3) translate([0,0,extra_rz[3][1]-d]) cylinder(r=extra_rz[3][0],h=d);
            }
            
            // flatten the cylinder for the dovetail
            reflect([1,0,0]) translate([3,objective_clip_y-0.5,dt_bottom]){
                cube(999);
            }
        }
        // add the dovetail
        translate([0,objective_clip_y,dt_bottom]){
            dovetail_m([objective_clip_w+4,objective_clip_y,dt_h],waist=dt_h-15);
        }
    }
}

module rms_mount_and_tube_lens_gripper(){
    // This assembly holds an RMS objective and a correcting
    // "tube" lens.
    union(){
        lens_gripper(lens_r=rms_r, lens_h=lens_assembly_h-2.5,h=lens_assembly_h, base_r=lens_assembly_base_r);
        lens_gripper(lens_r=tube_lens_r, lens_h=3.5,h=6);
        difference(){
            cylinder(r=tube_lens_aperture + 1.0,h=2);
            cylinder(r=tube_lens_aperture,h=999,center=true);
        }
    }
}
/*
/////////// Cover for camera board //////////////
module picam_cover(){
    // A cover for the camera PCB, slips over the bottom of the camera
    // mount.  This version should be compatible with v1 and v2 of the board
    start_y=-12+2.4;//-3.25;
    l=-start_y+12+2.4; //we start just after the socket and finish at 
    //the end of the board - this is that distance!
    difference(){
        union(){
            //base
            translate([-15,start_y,-4.3]) cube([25+5,l,4.3+d]);
            //grippers
            reflect([1,0,0]) translate([-15,start_y,0]){
                cube([2,l,4.5-d]);
                hull(){
                    translate([0,0,1.5]) cube([2,l,3]);
                    translate([0,0,4]) cube([2+2.5,l,0.5]);
                }
            }
        }
        translate([0,0,-1]) picam2_pcb_bottom();
        //chamfer the connector edge for ease of access
        translate([-999,start_y,0]) rotate([-135,0,0]) cube([9999,999,999]);
    }
} 
*/


module optics_module_single_lens(lens_outer_r, lens_aperture_r, lens_t, parfocal_distance){
    // This is the "classic" optics module, using the raspberry pi lens
    // It should be fitted to the smaller microscope body
    
    // Lens parameters are passed as arguments.
    ///picamera lens
    //lens_outer_r=3.04+0.2; //outer radius of lens (plus tape)
    //lens_aperture_r=2.2; //clear aperture of lens
    //lens_t=3.0; //thickness of lens
    //parfocal_distance = 6; //rough guess!
    
    // Maybe there should be a way to switch between LS and standard?
    dovetail_top = 27; //height of the top of the dovetail
    sample_z = 40; // height of the sample above the bottom of the microscope
    body_r = 8; // radius of the main part of the mount
    lens_z = sample_z - parfocal_distance; // position of lens
    neck_r=max( (body_r+lens_aperture_r)/2, lens_outer_r+1);
    neck_z = sample_z-5-2; // height of top of neck
    
    union(){
        // the bottom part is a camera mount, tapering to a neck
        difference(){
            // camera mount body, with a neck on top via extra_rz
            camera_mount_body(body_r=8, body_top=dovetail_top, dt_top=dovetail_top, extra_rz=[[neck_r,neck_z],[neck_r,lens_z+lens_t]]);
            // hole through the body for the beam
            optical_path(lens_aperture_r, lens_z);
            // cavity for the lens
            translate([0,0,lens_z]) cylinder(r=lens_outer_r,h=999);
        }
    }
}

module optics_module_rms(tube_lens_ffd=16.1, tube_lens_f=20, 
    tube_lens_r=16/2+0.2, objective_parfocal_distance=35, tube_length=160, fluorescence=false){
    // This optics module takes an RMS objective and a tube length correction lens.
    // important parameters are below:
        
    rms_r = 20/2; //radius of RMS thread, to be gripped by the mount
    //tube_lens_r (argument) is the radius of the tube lens
    //tube_lens_ffd (argument) is the front focal distance (from flat side to focus) - measure this.
    //tube_lens_f (argument) is the nominal focal length of the tube lens.
    tube_lens_aperture = tube_lens_r - 1.5; // clear aperture of the correction lens
    pedestal_h = 2; // height of tube lens above bottom of lens assembly
    //sample_z (microscope_parameters.scad) // height of the sample above the bottom of the microscope (depends on size of microscope)
    dovetail_top = min(27, sample_z-objective_parfocal_distance-1); //height of the top of the dovetail
    
    ///////////////// Lens position calculation //////////////////////////
    // calculate the position of the tube lens based on a thin-lens
    // approximation: the light is focussing from the objective shoulder
    // to a point 160mm away, but we want to refocus it so it's
    // closer (i.e. focusses at the bottom of the mount).  If we let:
    // dos = distance from objective to sensor
    // dts = distance from tube lens to sensor
    // ft = focal length of tube lens
    // fo = tube length of objective lens
    // then 1/dts = 1/ft + 1/(fo-dos+dts)
    // the solution to this, if b=fo-dos and a=ft, is:
    // dts = 1/2 * (sqrt(b) * sqrt(4*a+b) - b)
    a = tube_lens_f;
    dos = sample_z - objective_parfocal_distance - bottom;
    b = tube_length - dos;
    dts = 1/2 * (sqrt(b) * sqrt(4*a+b) - b);
    echo("Distance from tube lens principal plane to sensor:",dts);
    // that's the distance to the nominal "principal plane", in reality
    // we measure the front focal distance, and shift accordingly:
    tube_lens_z = bottom + dts - (tube_lens_f - tube_lens_ffd);
        
    // having calculated where the lens should go, now make the mount:
    lens_assembly_z = tube_lens_z - pedestal_h; //height of lens assembly
    lens_assembly_base_r = rms_r+1; //outer size of the lens grippers
    lens_assembly_h = sample_z-lens_assembly_z-objective_parfocal_distance; //the
        //objective sits parfocal_distance below the sample
    union(){
        // The bottom part is just a camera mount with a flat top
        difference(){
            // camera mount with a body that's shorter than the dovetail
            camera_mount_body(body_r=lens_assembly_base_r, bottom_r=10.5, body_top=lens_assembly_z, dt_top=dovetail_top,fluorescence=fluorescence);
            // camera cut-out and hole for the beam
            if(fluorescence){
                optical_path_fl(tube_lens_aperture, lens_assembly_z, fluorescence=fluorescence);
            }else{
                optical_path(tube_lens_aperture, lens_assembly_z);
            }
            // make sure it makes contact with the lens gripper, but
            // doesn't foul the inside of it
            translate([0,0,lens_assembly_z]) lens_gripper(lens_r=rms_r-d, lens_h=lens_assembly_h-2.5,h=lens_assembly_h, base_r=lens_assembly_base_r-d, solid=true); //same as the big gripper below
            
        }
        // A pair of nested lens grippers to hold the objective
        translate([0,0,lens_assembly_z]){
            // gripper for the objective
            lens_gripper(lens_r=rms_r, lens_h=lens_assembly_h-2.5,h=lens_assembly_h, base_r=lens_assembly_base_r);
            // gripper for the tube lens
            lens_gripper(lens_r=tube_lens_r, lens_h=pedestal_h+1,h=pedestal_h+1+2.5);
            // pedestal to raise the tube lens up within the gripper
            difference(){
                cylinder(r=tube_lens_aperture + 1.0,h=2);
                cylinder(r=tube_lens_aperture,h=999,center=true);
            }
        }
    }
}
module optics_module_trylinder(
        lens_r = 14/2, //radius of lens
        parfocal_distance = 20, //distance from back of lens to sample
        lens_h = 5.5 //height of lens (will be gripped 1mm below)
    ){
    // This optics module grips a single lens at the top.
    lens_aperture = lens_r - 1.5; // clear aperture of the lens
    pedestal_h = 2; // extra height on the gripper, to allow it to flex
    dovetail_top = min(27, sample_z-parfocal_distance+lens_h-1); //height of the top of the dovetail
    
    lens_z = sample_z - parfocal_distance; //axial position of lens
        
    // having calculated where the lens should go, now make the mount:
    lens_assembly_z = lens_z - pedestal_h; //height of lens assembly
    lens_assembly_base_r = lens_r+1; //outer size of the lens grippers
    lens_assembly_h = lens_h + pedestal_h; //the
                                            //lens sits parfocal_distance below the sample
    union(){
        // The bottom part is just a camera mount with a flat top
        difference(){
            // camera mount with a body that's shorter than the dovetail
            camera_mount_body(body_r=lens_assembly_base_r, bottom_r=10.5, body_top=lens_assembly_z, dt_top=lens_assembly_z);
            // camera cut-out and hole for the beam
            optical_path(lens_aperture, lens_assembly_z);
        }
        // A lens gripper to hold the objective
        translate([0,0,lens_assembly_z]){
            // gripper
            trylinder_gripper(inner_r=lens_r, grip_h=lens_assembly_h-1.5,h=lens_assembly_h, base_r=lens_assembly_base_r);
            // pedestal to raise the tube lens up within the gripper
            difference(){
                cylinder(r=lens_aperture + 1.0,h=pedestal_h);
                cylinder(r=lens_aperture,h=999,center=true);
            }
        }
    }
}

difference(){
    /*/ Optics module for pi camera lens, with standard stage (i.e. the classic)
    optics_module_single_lens(
        ///picamera lens
        lens_outer_r=3.04+0.2, //outer radius of lens (plus tape)
        lens_aperture_r=2.2, //clear aperture of lens
        lens_t=3.0, //thickness of lens
        parfocal_distance = 6 //sample to bottom of lens
    );//*/
    /*/ Optics module for RMS objective, using Comar 20mm singlet tube lens
    optics_module_rms(
        tube_lens_ffd=16.1, 
        tube_lens_f=20, 
        tube_lens_r=16/2+0.2, 
        objective_parfocal_distance=35
    );//*/
    /*/ Optics module for RMS objective, using Comar 31.5mm singlet tube lens
    optics_module_rms(
        tube_lens_ffd=28.5, 
        tube_lens_f=31.5, 
        tube_lens_r=16/2+0.1, 
        objective_parfocal_distance=45
    );//*/
    /*/ Optics module for RMS objective, using Comar 31.5mm, d=10mm singlet tube lens
    optics_module_rms(
        tube_lens_ffd=28.5, 
        tube_lens_f=31.5, 
        tube_lens_r=10/2+0.2, 
        objective_parfocal_distance=45
    );//*/
    /*/ Optics module for RMS objective, using Comar 40mm singlet tube lens
    optics_module_rms(
        tube_lens_ffd=38, 
        tube_lens_f=40, 
        tube_lens_r=16/2+0.1, 
        objective_parfocal_distance=35,
        fluorescence=true
    );//*/
    /*/ Optics module for USB camera's M12 lens
    optics_module_trylinder(
        lens_r = 14/2,
        parfocal_distance = 20,
        lens_h = 5.5
    );//*/
    //
    //picam_cover();
    //rotate([90,0,0]) cylinder(r=999,h=999,$fn=8);
    //mirror([0,0,1]) cylinder(r=999,h=999,$fn=8);
    //#translate([0,0,fl_cube_bottom]) rotate([90,0,0]) translate([0,0,-fl_cube_w/2]) fl_cube();
    mirror([0,1,0]) fl_led_mount();
}
