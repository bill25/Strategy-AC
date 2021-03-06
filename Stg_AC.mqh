//+------------------------------------------------------------------+
//|                  EA31337 - multi-strategy advanced trading robot |
//|                       Copyright 2016-2020, 31337 Investments Ltd |
//|                                       https://github.com/EA31337 |
//+------------------------------------------------------------------+

/**
 * @file
 * Implements AC strategy based on the Bill Williams' Accelerator/Decelerator oscillator.
 */

// Includes.
#include <EA31337-classes/Indicators/Indi_AC.mqh>
#include <EA31337-classes/Strategy.mqh>

// User input params.
INPUT string __AC_Parameters__ = "-- AC strategy params --";  // >>> AC <<<
INPUT int AC_Shift = 0;                                       // Shift (relative to the current bar, 0 - default)
INPUT int AC_SignalOpenMethod = 1;                            // Signal open method (0-1)
INPUT double AC_SignalOpenLevel = 0.0004;                     // Signal open level (>0.0001)
INPUT int AC_SignalOpenFilterMethod = 0;                      // Signal open filter method
INPUT int AC_SignalOpenBoostMethod = 0;                       // Signal open boost method
INPUT int AC_SignalCloseMethod = 0;                           // Signal close method
INPUT double AC_SignalCloseLevel = 0;                         // Signal close level
INPUT int AC_PriceLimitMethod = 0;                            // Price limit method
INPUT double AC_PriceLimitLevel = 2;                          // Price limit level
INPUT double AC_MaxSpread = 6.0;                              // Max spread to trade (pips)

// Struct to define strategy parameters to override.
struct Stg_AC_Params : StgParams {
  unsigned int AC_Period;
  ENUM_APPLIED_PRICE AC_Applied_Price;
  int AC_Shift;
  int AC_SignalOpenMethod;
  double AC_SignalOpenLevel;
  int AC_SignalOpenFilterMethod;
  int AC_SignalOpenBoostMethod;
  int AC_SignalCloseMethod;
  double AC_SignalCloseLevel;
  int AC_PriceLimitMethod;
  double AC_PriceLimitLevel;
  double AC_MaxSpread;

  // Constructor: Set default param values.
  Stg_AC_Params()
      : AC_Shift(::AC_Shift),
        AC_SignalOpenMethod(::AC_SignalOpenMethod),
        AC_SignalOpenLevel(::AC_SignalOpenLevel),
        AC_SignalOpenFilterMethod(::AC_SignalOpenFilterMethod),
        AC_SignalOpenBoostMethod(::AC_SignalOpenBoostMethod),
        AC_SignalCloseMethod(::AC_SignalCloseMethod),
        AC_SignalCloseLevel(::AC_SignalCloseLevel),
        AC_PriceLimitMethod(::AC_PriceLimitMethod),
        AC_PriceLimitLevel(::AC_PriceLimitLevel),
        AC_MaxSpread(::AC_MaxSpread) {}
};

// Loads pair specific param values.
#include "sets/EURUSD_H1.h"
#include "sets/EURUSD_H4.h"
#include "sets/EURUSD_M1.h"
#include "sets/EURUSD_M15.h"
#include "sets/EURUSD_M30.h"
#include "sets/EURUSD_M5.h"

class Stg_AC : public Strategy {
 public:
  Stg_AC(StgParams &_params, string _name) : Strategy(_params, _name) {}

  static Stg_AC *Init(ENUM_TIMEFRAMES _tf = NULL, long _magic_no = NULL, ENUM_LOG_LEVEL _log_level = V_INFO) {
    // Initialize strategy initial values.
    Stg_AC_Params _params;
    if (!Terminal::IsOptimization()) {
      SetParamsByTf<Stg_AC_Params>(_params, _tf, stg_ac_m1, stg_ac_m5, stg_ac_m15, stg_ac_m30, stg_ac_h1, stg_ac_h4,
                                   stg_ac_h4);
    }
    // Initialize strategy parameters.
    ACParams ac_params(_tf);
    StgParams sparams(new Trade(_tf, _Symbol), new Indi_AC(ac_params), NULL, NULL);
    sparams.logger.SetLevel(_log_level);
    sparams.SetMagicNo(_magic_no);
    sparams.SetSignals(_params.AC_SignalOpenMethod, _params.AC_SignalOpenLevel, _params.AC_SignalOpenFilterMethod,
                       _params.AC_SignalOpenBoostMethod, _params.AC_SignalCloseMethod, _params.AC_SignalCloseLevel);
    sparams.SetPriceLimits(_params.AC_PriceLimitMethod, _params.AC_PriceLimitLevel);
    sparams.SetMaxSpread(_params.AC_MaxSpread);
    // Initialize strategy instance.
    Strategy *_strat = new Stg_AC(sparams, "AC");
    return _strat;
  }

  /**
   * Check strategy's opening signal.
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method = 0, double _level = 0.0) {
    Indicator *_indi = Data();
    bool _is_valid = _indi[CURR].IsValid();
    bool _result = _is_valid;
    switch (_cmd) {
      case ORDER_TYPE_BUY:
        // Buy: if the indicator is above zero and 2 consecutive columns are green or if the indicator is below zero and ...
        // ... 1 consecutive column is green.
        _result &= _indi[0].value[0] > _level && _indi[0].value[0] > _indi[1].value[0];
        if (_method != 0) {
          if (METHOD(_method, 0)) _result &= _indi[1].value[0] > _indi[2].value[0]; // ... 2 consecutive columns are green.
          if (METHOD(_method, 1)) _result &= _indi[2].value[0] > _indi[3].value[0]; // ... 3 consecutive columns are green.
          if (METHOD(_method, 2)) _result &= _indi[3].value[0] > _indi[4].value[0]; // ... 4 consecutive columns are green.
        }
        break;
      case ORDER_TYPE_SELL:
        // Sell: if the indicator is below zero and 2 consecutive columns are red or if the indicator is above zero and ...
        // ... 1 consecutive column is red.
        _result &= _indi[0].value[0] < -_level && _indi[0].value[0] < _indi[1].value[0];
        if (_method != 0) {
          if (METHOD(_method, 0)) _result &= _indi[1].value[0] < _indi[2].value[0]; // ... 2 consecutive columns are red.
          if (METHOD(_method, 1)) _result &= _indi[2].value[0] < _indi[3].value[0]; // ... 3 consecutive columns are red.
          if (METHOD(_method, 2)) _result &= _indi[3].value[0] < _indi[4].value[0]; // ... 4 consecutive columns are red.
        }
        break;
    }
    return _result;
  }

  /**
   * Check strategy's opening signal additional filter.
   */
  bool SignalOpenFilter(ENUM_ORDER_TYPE _cmd, int _method = 0) {
    bool _result = true;
    if (_method != 0) {
      // if (METHOD(_method, 0)) _result &= Trade().IsTrend(_cmd);
      // if (METHOD(_method, 1)) _result &= Trade().IsPivot(_cmd);
      // if (METHOD(_method, 2)) _result &= Trade().IsPeakHours(_cmd);
      // if (METHOD(_method, 3)) _result &= Trade().IsRoundNumber(_cmd);
      // if (METHOD(_method, 4)) _result &= Trade().IsHedging(_cmd);
      // if (METHOD(_method, 5)) _result &= Trade().IsPeakBar(_cmd);
    }
    return _result;
  }

  /**
   * Gets strategy's lot size boost (when enabled).
   */
  double SignalOpenBoost(ENUM_ORDER_TYPE _cmd, int _method = 0) {
    bool _result = 1.0;
    if (_method != 0) {
      // if (METHOD(_method, 0)) if (Trade().IsTrend(_cmd)) _result *= 1.1;
      // if (METHOD(_method, 1)) if (Trade().IsPivot(_cmd)) _result *= 1.1;
      // if (METHOD(_method, 2)) if (Trade().IsPeakHours(_cmd)) _result *= 1.1;
      // if (METHOD(_method, 3)) if (Trade().IsRoundNumber(_cmd)) _result *= 1.1;
      // if (METHOD(_method, 4)) if (Trade().IsHedging(_cmd)) _result *= 1.1;
      // if (METHOD(_method, 5)) if (Trade().IsPeakBar(_cmd)) _result *= 1.1;
    }
    return _result;
  }

  /**
   * Check strategy's closing signal.
   *
   */
  bool SignalClose(ENUM_ORDER_TYPE _cmd, int _method = 0, double _level = 0.0) {
    return SignalOpen(Order::NegateOrderType(_cmd), _method, _level);
  }

  /**
   * Gets price limit value for profit take or stop loss.
   */
  double PriceLimit(ENUM_ORDER_TYPE _cmd, ENUM_ORDER_TYPE_VALUE _mode, int _method = 0, double _level = 0.0) {
    Indicator *_indi = Data();
    double _trail = _level * Market().GetPipSize();
    int _bar_count = (int) _level * 10;
    int _direction = Order::OrderDirection(_cmd, _mode);
    double _default_value = Market().GetCloseOffer(_cmd) + _trail * _method * _direction;
    double _result = _default_value;
    ENUM_APPLIED_PRICE _ap = _direction > 0 ? PRICE_HIGH : PRICE_LOW;
    switch (_method) {
      case 0:
        _result = _indi.GetPrice(_ap, _direction > 0 ? _indi.GetHighest(_bar_count) : _indi.GetLowest(_bar_count));
        break;
    }
    return _result;
  }
};