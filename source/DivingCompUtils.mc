using Toybox.Math as Math;
using Toybox.System;


var g0 = 9.81;          //  [m/s^2]
var rho_w = 1030;       //  water density [kg/m^3]
var P_N_rat = 0.78;     //  Nitrogen partial pressure in breathing gas
var T = 10000; // A really long time
var BAR2PSC = 100000.0d;
var PSC2BAR = 1/BAR2PSC;

var P_comp = new [16];
var P_amb_tol = new [16];
var NDT_all = new [16];
var deco_flag = 0;

var TAB = [
    [5.0, 1.1696, 0.5578],
    [8.0, 1.0,   0.6514],
    [12.5, 0.8618,  0.7222],
    [18.5, 0.7562,  0.7825],
    [27.0, 0.6667,  0.8126],
    [38.3, 0.560,   0.8434],
    [54.3, 0.4947,  0.8693],
    [77.0, 0.45,    0.8910],
    [109.0, 0.4187,  0.9092],
    [146.0, 0.3798,  0.9222],
    [187.0, 0.3497,  0.9319],
    [239.0, 0.3223,  0.9403],
    [305.0, 0.2850,  0.9477],
    [390.0, 0.2737,  0.9544],
    [498.0, 0.2523,  0.9602],
    [635.0, 0.2327,  0.9653]];

class DivingCompUtils
{

    function initialize() {
    }


    static function update_decompression(p_amb,P_surf, P_comp0,gf_cur,dt)
    {
      var depth = calc_real_depth(p_amb,P_surf);
      var P_gas =  P_N_rat * p_amb;
      var P_long = new[16];


      for( var i = 0; i < 16; i += 1 )
      {
        var t_ht = TAB[i][0];
        var a = TAB[i][1];
        var b = TAB[i][2];

        P_comp[i] = P_comp0[i] + (P_gas-P_comp0[i])*(1-Math.pow(2.0,(-dt/60.0/t_ht)));
        /*
        if(i == 15)
        {
          System.println(P_comp[i]);
          System.println(a);
          System.println(gf_cur);
          System.println(b);
        }
        */
        P_amb_tol[i] = (P_comp[i]-a*gf_cur)/(gf_cur/b-gf_cur+1.0);

        if (P_amb_tol[i] > p_amb)
        {
            deco_flag = 1;
        }

        if (P_amb_tol[i] > P_surf)
        {
            NDT_all[i] = 0.0;
            continue;
        }

        P_long[i] = P_comp0[i] + (P_gas - P_comp0[i])*(1-Math.pow(2.0,(-T/t_ht)));
        var P_amb_long = (P_long[i]-a*gf_cur)/(gf_cur/b-gf_cur+1.0);

        if (P_amb_long < P_surf)
        {
            NDT_all[i]=99999.0;
        }
        else
        {
            var C1 = gf_cur/b-gf_cur+1;
            var C2 = P_gas-P_comp0[i];
            NDT_all[i]=-t_ht*Math.log((1.0+P_comp0[i]/C2-C1/C2*P_surf-a*gf_cur/C2),2.0);
        }
      }

      var P_amb_max = max(P_amb_tol,16);
      var ceiling = (P_amb_max-P_surf)/rho_w/g0*100000;

      if (ceiling<0)
      {
          ceiling=0;
      }

      var NDT = min(NDT_all,16);
      if (NDT<0)
      {
          NDT=0;
      }
      var ret_dict = {
        "depth" => depth, 
        "NDT" => NDT, 
        "P_comp" => P_comp, 
        "P_amb_tol" => P_amb_tol, 
        "deco_flag" => deco_flag ,
        "ceiling" => ceiling,
        "P_long" => P_long,
        "NDT_all" => NDT_all
      };
      return ret_dict;
    }


    static function ndt_time_at_depth_at_surf_time(P_surf,P_comp0,wanted_dive_depth,surf_time)
    {

      var P_gas =  P_N_rat * P_surf;
      var P_comp_temp = new [16];
      for( var i = 0; i < 16; i += 1 )
      {
        var t_ht = TAB[i][0];
        var a = TAB[i][1];
        var b = TAB[i][2];

        P_comp_temp[i] = P_comp0[i] + (P_gas-P_comp0[i])*(1-Math.pow(2.0,(-surf_time/60.0/t_ht)));
      }
      return ndt_time_at_depth(P_surf,P_comp_temp,wanted_dive_depth);
    }


    static function ndt_time_at_depth(P_surf,P_comp0,wanted_dive_depth)
    {
      var gf_high = 0.85;

      var p_amb = P_surf+rho_w*g0*wanted_dive_depth*PSC2BAR;
      var P_gas = P_N_rat*p_amb;

      for( var i = 0; i < 16; i += 1 )
      {
          var t_ht = TAB[i][0];
          var a = TAB[i][1];
          var b = TAB[i][2];

          var P_long = P_comp0[i] + (P_gas - P_comp0[i])*(1-Math.pow(2.0,(-T/t_ht)));

          var P_amb_long = (P_long-a*gf_high)/(gf_high/b-gf_high+1.0);

          if (P_amb_long < P_surf)
          {
              NDT_all[i]=99999.0;
          }
          else
          {
              var C1 = gf_high/b-gf_high+1;
              var C2 = P_gas-P_comp0[i];
              NDT_all[i]=-t_ht*Math.log((1.0+P_comp0[i]/C2-C1/C2*P_surf-a*gf_high/C2),2.0);
          }

      }

      var NDT = min(NDT_all,16);
      if (NDT<0)
      {
          NDT=0;
      }
      return NDT;
    }


    static function time_to_fly(P_surf,P_comp0)
    {
      var gf_low = 0.3;
      var h_cabin = 2500.0; //cabin pressure altitude [m]
      var T_surf = 285.0;   //[K]
      var Lb = -6.5e-3;   //[deg/m]
      var R = 287.0;
      var p_cabin = P_surf * Math.pow((T_surf/(T_surf+Lb*h_cabin)),(g0/R/Lb));
      var p_NE = p_cabin;

      var p_amb = P_surf;
      var P_gas = P_N_rat*p_amb;

      for (var i=0; i<16; i += 1)
      {
          var t_ht = TAB[i][0];
          var a = TAB[i][1];
          var b = TAB[i][2];

          var p_amb_tol = (P_comp0[i]-a*gf_low)/(gf_low/b-gf_low+1.0);

          if (p_amb_tol < p_NE)
          {
            NDT_all[i] = 0;
          } else {
            var C1 = gf_low/b-gf_low+1;
            var C2 = P_gas-P_comp0[i];

            if (C2 == 0)
            {
              NDT_all[i] = 0;
            } else {
              NDT_all[i]=-t_ht*Math.log((1.0+P_comp0[i]/C2-C1/C2*p_NE-a*gf_low/C2),2.0);
            }
          }
      }
      var TTF = max(NDT_all,16);
      if (TTF < 0)
      {
        TTF = 0;
      }
      return TTF;
    }


    static function calc_p_amb(T,H,P)
    {
      var R = 287.0d;
      var L = -6.5e-3d;

      var T0 = T+273.15;

      var x = T0/(T0+L*H);
      var y = -1.0 * (g0/R/L);
      var p =  P*(1.0d/Math.pow(x,y));

      return p*PSC2BAR;
    }

    static function calc_real_depth(p_amb,P_surf)
    {
      var depth = (p_amb-P_surf)/rho_w/g0*BAR2PSC;
      return depth;
    }


    static function min(arr, size)
    {
      var min_idx = 0;
      for(var i=0; i<size; i+= 1)
      {
        if (arr[i] < arr[min_idx])
        {
          min_idx = i;
        }
      }
      return arr[min_idx];
    }

    static function max(arr, size)
    {
      var max_idx = 0;
      for(var i=0; i<size; i+= 1)
      {
        if (arr[i] > arr[max_idx])
        {
          max_idx = i;
        }
      }
      return arr[max_idx];
    }

}
