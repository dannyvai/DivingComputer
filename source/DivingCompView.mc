//
// Copyright 2016 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Timer as Timer;
using Toybox.Activity as Act;
using Toybox.Math as Math;
using Toybox.Time;
using Toybox.Application;
using Toybox.ActivityRecording;
using Toybox.Lang;

//TODO
using Toybox.Attention;


using DivingCompUtils;

var gf_low = 0.3;
var gf_high = 0.85;
var depth_threshold = 0.5;
var directions = ["N","NE","E","SE","S","SW","W","NW"];


class DivingCompView extends Ui.View {
    var timer1;

    var initialized = false;

    var P_comp0 =  new[16];
    var NDT = 0.0;
    var P_amb_tol =  new[16];
    var deco_flag;
    var ceiling = 0.0;
    var depth = 0.0;
    var max_depth = 0.0;

    var T,H,P,D;
    var gf_cur = gf_high;
    var cur_p_amb;
    var P_surf;
    var heading = 0.0;

    var lastSurfTime = 0;
    var surface_time = 0;
    var saftey_stop_time = 0;
    var diving_time = 0;
    var exitAppTime = 0;

    //Fit recording params
    var app;
    var session;
    var ndt_session_field = null;
    var depth_session_field = null;
    var gf_session_field = null;
    var ceiling_session_field = null;
    var watch_p_session_field = null;
    var p_surf_session_field = null;
    var p_amb_session_field = null;

    //Debug
    var P_long = new[16];
    var NDT_all = new[16];
    var p_comp_0_session_field = null;
    var p_comp_15_session_field = null;
    var plan_10m_session_field = null;
    var plan_20m_session_field = null;
    var plan_30m_session_field = null;
    var ttf_session_field = null;
    var ndt_after_5min_at_30m_session_field = null;
    var ndt_after_20min_at_30m_session_field = null;
    var ndt_after_40min_at_30m_session_field = null;


    function initialize() {
        Ui.View.initialize();

        if (Attention has :backlight) {
            Attention.backlight(true);
        }

        Sensor.setEnabledSensors( [Sensor.SENSOR_TEMPERATURE] );
        Sensor.enableSensorEvents( method(:onSensor) );
        self.app = Application.getApp();

        self.session = ActivityRecording.createSession(       // set up recording session
            {
             :name=>"diving_"+Time.now().value(),                               // set session name
             :sport=>ActivityRecording.SPORT_GENERIC,        // set sport type
             :subSport=>ActivityRecording.SUB_SPORT_GENERIC  // set sub sport type
            }
        );

        self.ndt_session_field =self.session.createField(
            "NDT",
            0,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"min"}
        );
        self.depth_session_field =self.session.createField(
            "depth",
            1,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"m"}
        );
        self.gf_session_field =self.session.createField(
            "gf",
            2,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>""}
        );
        self.ceiling_session_field =self.session.createField(
            "ceiling",
            3,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"m"}
        );
        /*
        self.watch_p_session_field = self.session.createField(
            "watch_p",
            4,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"bar"}
        );*/
        self.p_surf_session_field = self.session.createField(
            "P_surf",
            5,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"bar"}
        );
        self.p_amb_session_field = self.session.createField(
            "P_amb",
            6,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"bar"}
        );
        self.p_comp_0_session_field = self.session.createField(
            "P_comp_0",
            7,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"bar"}
        );

        self.p_comp_15_session_field = self.session.createField(
            "P_comp_15",
            8,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"bar"}
        );
        /*
        self.plan_10m_session_field = self.session.createField(
            "plan_10m_ndt",
            9,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"min"}
        );
        self.plan_20m_session_field = self.session.createField(
            "plan_20m_ndt",
            10,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"min"}
        );
        self.plan_30m_session_field = self.session.createField(
            "plan_30m_ndt",
            11,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"min"}
        );
        */
        self.ttf_session_field = self.session.createField(
            "ttf",
            12,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"min"}
        );
        /*
        self.ndt_after_5min_at_30m_session_field = self.session.createField(
            "ndt_5min_30m",
            13,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"min"}
        );
        self.ndt_after_20min_at_30m_session_field = self.session.createField(
            "ndt_20min_30m",
            14,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"min"}
        );
        self.ndt_after_40min_at_30m_session_field = self.session.createField(
            "ndt_40min_30m",
            15,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"min"}
        );
        */


        self.session.start();
    }

    function onSensor(sensorInfo)
    {
     var info = Act.getActivityInfo();

      T = sensorInfo.temperature;
      if (T == null){ T = 15.0; }
      //System.println(T);

      H = info.altitude;
      if (H== null){ H = 0.0; }
      //System.println(H);

      P = sensorInfo.pressure;
      if (P == null){ P = 0.0; }
      //System.println(P);

      self.heading = ((info.currentHeading*180.0/Math.PI)+360.0).toLong()%360;

      if (!initialized)
      {
        self.max_depth = 0.0;
        self.saftey_stop_time = 0.0;
        self.diving_time = 0;
        self.P_surf = DivingCompUtils.calc_p_amb(T,H,P);

        var P_comp0_temp = self.app.getProperty("P_comp0");
        var lastSurfTime_temp = self.app.getProperty("lastSurfTime");
        var exitAppTime_temp = self.app.getProperty("exitAppTime");

        if (lastSurfTime_temp == null || P_comp0_temp == null || P_comp0_temp[0] == null || exitAppTime_temp == null)
        {
          for( var i = 0; i < 16; i += 1 )
          {
              self.P_comp0[i] = P_N_rat*self.P_surf;

              //Debug
              self.P_long[i] = 0;
              self.NDT_all[i] = 0;
          }
          self.lastSurfTime = Time.now().value()-1;
          self.exitAppTime = Time.now().value();
        } else {
          self.P_comp0 = P_comp0_temp;
          self.lastSurfTime = lastSurfTime_temp;
          self.exitAppTime = exitAppTime_temp;
        }
        var now = Time.now().value();

        var dt = now - self.exitAppTime;
        self.surface_time = now - self.lastSurfTime;
        self.cur_p_amb = self.P_surf;
        if (lastSurfTime_temp != null && P_comp0_temp != null && P_comp0_temp[0] != null && exitAppTime_temp != null)
        {
          self.P_comp0 = P_comp0_temp;
        }

        update_decompression(dt.toFloat());

        initialized = true;
        return;
      }

      self.cur_p_amb = DivingCompUtils.calc_p_amb(T,H,P);
    }


    function update_decompression(dt)
    {
        //System.println("Calculating deco for " + dt + " seconds");
        var ret = DivingCompUtils.update_decompression(self.cur_p_amb,self.P_surf, self.P_comp0, self.gf_cur,dt);
        self.P_comp0 = ret["P_comp"];
        self.depth = ret["depth"];
        self.NDT = ret["NDT"];
        self.P_amb_tol = ret["P_amb_tol"];
        self.deco_flag = ret["deco_flag"];
        self.ceiling = ret["ceiling"];

        self.P_long = ret["P_long"];
        self.NDT_all = ret["NDT_all"];

        self.ndt_session_field.setData(self.NDT);
        self.depth_session_field.setData(self.depth);
        self.gf_session_field.setData(self.gf_cur);
        self.ceiling_session_field.setData(self.ceiling);
        //self.watch_p_session_field.setData(self.P);
        self.p_surf_session_field.setData(self.P_surf);
        self.p_amb_session_field.setData(self.cur_p_amb);

        //DEBUG
        self.p_comp_0_session_field.setData(self.P_comp0[0]);
        self.p_comp_15_session_field.setData(self.P_comp0[15]);
        //self.plan_10m_session_field.setData(DivingCompUtils.ndt_time_at_depth(self.P_surf,self.P_comp0,10.0));
        //self.plan_20m_session_field.setData(DivingCompUtils.ndt_time_at_depth(self.P_surf,self.P_comp0,20.0));
        //self.plan_30m_session_field.setData(DivingCompUtils.ndt_time_at_depth(self.P_surf,self.P_comp0,30.0));
        self.ttf_session_field.setData(DivingCompUtils.time_to_fly(self.P_surf,self.P_comp0));

        //self.ndt_after_5min_at_30m_session_field.setData(DivingCompUtils.ndt_time_at_depth_at_surf_time(self.P_surf,self.P_comp0,30.0,5.0*60));
        //self.ndt_after_20min_at_30m_session_field.setData(DivingCompUtils.ndt_time_at_depth_at_surf_time(self.P_surf,self.P_comp0,30.0,20.0*60));
        //self.ndt_after_40min_at_30m_session_field.setData(DivingCompUtils.ndt_time_at_depth_at_surf_time(self.P_surf,self.P_comp0,30.0,40.0*60));

    }

    function callback1() {

        //If not initialized can't do calculations
        if( !initialized)
        {
          return;
        }

        update_decompression(1.0);


        if (self.depth > self.max_depth)
        {
          self.max_depth = self.depth;
        }
        

        //Control surface time/divin time/max depth reseting
        if (self.depth < depth_threshold)
        {
          self.surface_time += 1;
          if (self.surface_time == 1)
          {
            self.lastSurfTime = Time.now().value();
          }

          if (surface_time > 600) //10min
          {
            self.max_depth = 0;
            self.diving_time = 0;
            self.saftey_stop_time = 0;
          }

        } else {
          self.diving_time += 1;
          self.surface_time = 0;
        }

        //Ascending gradiant changes
        if( self.max_depth != 0 && self.NDT == 0 )
        {
          self.gf_cur = gf_high - (gf_high-gf_low)/self.max_depth*self.depth;
        } else {
          self.gf_cur = gf_high;
        }
        
        //Safety stop
        if( self.max_depth > 20.0)
        {
          if (self.depth > 4.0 && self.depth < 6.0)
          {
            self.saftey_stop_time += 1;
          }
          if (self.depth < 0.5 || self.depth > 10.0)
          {
            self.saftey_stop_time = 0;
          }
        }


        Ui.requestUpdate();
    }

    function onLayout(dc) {
        timer1 = new Timer.Timer();
        timer1.start(method(:callback1), 1000, true);
    }

    function onUpdate(dc) {
        var string;

        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);


        if (self.surface_time > 0)
        {

          var min = (self.surface_time/60).toNumber();
          var sec = (self.surface_time%60).toNumber();
          string = "Surface T: " + min.format("%02d")+":"+sec.format("%02d");
          dc.drawText(20, (dc.getHeight() / 2) -70, Gfx.FONT_SMALL, string, Gfx.TEXT_JUSTIFY_LEFT);


          min = (self.diving_time/60).toNumber();
          sec = (self.diving_time%60).toNumber();
          string = "Diving T: " + min.format("%02d")+":"+sec.format("%02d");
          dc.drawText(20, (dc.getHeight() / 2) -50, Gfx.FONT_SMALL, string, Gfx.TEXT_JUSTIFY_LEFT);

          string = "Max Depth: " + self.max_depth.format("%02.1f") +"m";
          dc.drawText(20, (dc.getHeight() / 2) - 30, Gfx.FONT_SMALL, string, Gfx.TEXT_JUSTIFY_LEFT);
          
  
          string = "Heading: " + self.heading.toLong()+ " ("+directions[Math.round(self.heading/45.0).toNumber()%8] +")";
          dc.drawText(20, (dc.getHeight() / 2) - 10, Gfx.FONT_SMALL, string, Gfx.TEXT_JUSTIFY_LEFT);
       

          var ndt_at_20m = DivingCompUtils.ndt_time_at_depth(self.P_surf,self.P_comp0,20.0)*60;
          min = (ndt_at_20m.toLong()/60);
          sec = (ndt_at_20m.toLong()%60);
          string = "NDT@20m: " +min.format("%02d")+":"+sec.format("%02d");
          dc.drawText(20, (dc.getHeight() / 2) +10, Gfx.FONT_SMALL, string, Gfx.TEXT_JUSTIFY_LEFT);

          var ndt_at_30m = DivingCompUtils.ndt_time_at_depth(self.P_surf,self.P_comp0,30.0)*60;
          min = (ndt_at_30m.toLong()/60);
          sec = (ndt_at_30m.toLong()%60);
          string = "NDT@30m: " +min.format("%02d")+":"+sec.format("%02d");
          dc.drawText(20, (dc.getHeight() / 2) + 30, Gfx.FONT_SMALL, string, Gfx.TEXT_JUSTIFY_LEFT);
          
          var TTF = DivingCompUtils.time_to_fly(self.P_surf,self.P_comp0);
          var hours = Math.ceil(TTF/60.0).toLong();
          string = "TTF: " +hours.format("%d") + " Hours";
          dc.drawText(20, (dc.getHeight() / 2) + 50, Gfx.FONT_SMALL, string, Gfx.TEXT_JUSTIFY_LEFT);
          

        } else {


          var min = (self.diving_time/60).toNumber();
          var sec = (self.diving_time%60).toNumber();
          string = "Diving T: " + min.format("%02d")+":"+sec.format("%02d");
          dc.drawText(20, (dc.getHeight() / 2) -70, Gfx.FONT_SMALL, string, Gfx.TEXT_JUSTIFY_LEFT);

          string = "Depth: " + self.depth.format("%02.1f")+"m";
          dc.drawText(20, (dc.getHeight() / 2) -50, Gfx.FONT_SMALL, string, Gfx.TEXT_JUSTIFY_LEFT);

          if (self.ceiling > 0)
          {
            string = "Ceiling: " + self.ceiling.format("%02.1f") +"m";
            dc.drawText(20, (dc.getHeight() / 2) - 30, Gfx.FONT_SMALL, string, Gfx.TEXT_JUSTIFY_LEFT);
          } else {
            var ndt_temp = (self.NDT*60.0).toLong();
            var min = (ndt_temp/60).toNumber();
            var sec = (ndt_temp%60).toNumber();
            string = "NDT: " + min.format("%02d")+":"+sec.format("%02d");
            dc.drawText(20, (dc.getHeight() / 2) - 30, Gfx.FONT_SMALL, string, Gfx.TEXT_JUSTIFY_LEFT);
          }

          string = "Max Depth: " + self.max_depth.format("%02.1f") +"m";
          dc.drawText(20, (dc.getHeight() / 2) - 10, Gfx.FONT_SMALL, string, Gfx.TEXT_JUSTIFY_LEFT);




          string = "Heading: " + self.heading.toLong()+ " ("+directions[Math.round(self.heading/45.0).toNumber()%8] +")";
          dc.drawText(20, (dc.getHeight() / 2) + 10, Gfx.FONT_SMALL, string, Gfx.TEXT_JUSTIFY_LEFT);
       
          if (self.saftey_stop_time > 0)
          {
            var min = (self.saftey_stop_time/60).toNumber();
            var sec = (self.saftey_stop_time%60).toNumber();
            string = "Safety Stop: " + min.format("%02d")+":"+sec.format("%02d");
            dc.drawText(20, (dc.getHeight() / 2) + 30, Gfx.FONT_SMALL, string, Gfx.TEXT_JUSTIFY_LEFT);
          }
        }



    }

    function onHide(){
      self.app.setProperty("P_comp0",P_comp0);
      self.app.setProperty("lastSurfTime",self.lastSurfTime);
      self.app.setProperty("exitAppTime",Time.now().value());      
      self.session.stop();
    }


}
