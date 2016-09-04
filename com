// JavaScript Document
var Calendar = Class.create()

Calendar.VERSION = '1.0'
Calendar.DAY_NAMES =new Array('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday','Sunday')
Calendar.SHORT_DAY_NAMES = new Array('S', 'M', 'T', 'W', 'T', 'F', 'S', 'S')
Calendar.MONTH_NAMES = new Array('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August','September', 'October', 'November', 'December')
Calendar.SHORT_MONTH_NAMES = new Array(  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov','Dec')

Calendar.NAV_PREVIOUS_YEAR = -2
Calendar.NAV_PREVIOUS_MONTH = -1
Calendar.NAV_TODAY = 0
Calendar.NAV_NEXT_MONTH = 1
Calendar.NAV_NEXT_YEAR = 2

Calendar._checkCalendar = function(event){
	if(!window._popupCalendar) return false
	if(Element.descendantOf(Event.element(event),window._popupCalendar.container))return
	window._popupCalendar.callCloseHandler()
	return Event.stop(event)
}

Calendar.defaultSelectHandler = function(calendar)
{
	if(!calendar.dateField)return false
	
	//update datefield value
	if(calendar.dateField.tagName == 'INPUT'){
		calendar.dateField.value = calendar.date.print(calendar.dateFormat)
	}
	
	//Trigger the onchange callback on the dateField,if one has been defined
	if(typeof calendar.dateField.onchange == 'function'){
		calendar.dateField.onchange()	
	}
	if(calendar.shouldClose) calendar.callCloseHandler()
}
Calendar.defaultCloseHandler = function(calendar){
	calendar.hide()
}
Calendar.handleMouseDownEvent = function(event){
	var el = Event.element(event)
	var calendar = el.calendar
	var isNewDate = false
	
	if(!calendar) return false
	
	//Clicked on a day
	if(typeof el.navAction == 'undefined'){
		if(calendar.currentDateElement){
			Element.removeClassName(calendar.currentDateElement,'selected')
			Element.addClassName(el,'selected')
			calendar.shouldClose = (calendar.currentDateElement == el)
			if(!calendar.shouldClose) calendar.currentDateElement = el
		}
		calendar.date.setDateOnly(el.date)
		isNewDate = true
		calendar.shouldClose = !el.hasClassName('otherDay')
		var isOtherMonth = !calendar.shouldClose
		if(isOtherMonth) calendar.update(calendar.date)
	}
	
	//Clicked on an action button
	else{
		var date = new Date(calendar.date)	
		
		    if (el.navAction == Calendar.NAV_TODAY)
      date.setDateOnly(new Date())

    var year = date.getFullYear()
    var mon = date.getMonth()
    function setMonth(m) {
      var day = date.getDate()
      var max = date.getMonthDays(m)
      if (day > max) date.setDate(max)
      date.setMonth(m)
    }
    switch (el.navAction) {

      // Previous Year
      case Calendar.NAV_PREVIOUS_YEAR:
        if (year > calendar.minYear)
          date.setFullYear(year - 1)
        break

      // Previous Month
      case Calendar.NAV_PREVIOUS_MONTH:
        if (mon > 0) {
          setMonth(mon - 1)
        }
        else if (year-- > calendar.minYear) {
          date.setFullYear(year)
          setMonth(11)
        }
        break

      // Today
      case Calendar.NAV_TODAY:
        break

      // Next Month
      case Calendar.NAV_NEXT_MONTH:
        if (mon < 11) {
          setMonth(mon + 1)
        }
        else if (year < calendar.maxYear) {
          date.setFullYear(year + 1)
          setMonth(0)
        }
        break

      // Next Year
      case Calendar.NAV_NEXT_YEAR:
        if (year < calendar.maxYear)
          date.setFullYear(year + 1)
        break

    }
	if(!date.equalsTo(calendar.date)){
		calendar.setDate(date)
		isNewDate =true
	}else if(el.navAction == 0){
		isNewDate = (calendar.shouldClose = true)
	}
	}
	if (isNewDate) event && calendar.callSelectHandler()
 	 if (calendar.shouldClose) event && calendar.callCloseHandler()
	 
	 Event.stopObserving(document,'mousedown',Calendar.handleMouseDownEvent)
	 
  return Event.stop(event)	
}
//------------------------------------------------------------------------------
// Static Methods
//------------------------------------------------------------------------------
Calendar.setup = function(params){
	function param_default(name,def){
		if(!params[name])params[name] = def
	}
	
	param_default('dateField',null)
	param_default('triggerElement',null)
	param_default('selectHandler',null)
	param_default('closeHandler',null)
	
	var triggerElement = $(params.triggerElement)
	var calendar = new Calendar(triggerElement)
    triggerElement.onclick = function() {
		  calendar.setSelectHandler(params.selectHandler || Calendar.defaultSelectHandler)
		  calendar.setCloseHandler(params.closeHandler || Calendar.defaultCloseHandler)
		  if(params.dateFormat)
			  calendar.setDateFormat(params.dateFormat)
		  if(params.dateField){
			  calendar.setDateField(params.dateField)	
			  calendar.parseDate(calendar.dateField.innerHTML || calendar.dateField.value)
			  Date.parseDate(calendar.dateField.value || calendar.dateField.innerHTML,calendar.dateFormat)
			  calendar.showAtElement(calendar.dateField)
			  return calendar
			  
		  }
	}
	//var calendar = new Calendar()
	//calendar.setSelectHandler(params.selectHandler || Calendar.defaultSelectHandler)
}


//------------------------------------------------------------------------------
// Calendar Instance
//------------------------------------------------------------------------------
Calendar.prototype = {
	//The HTML container element
	container:null,
	
	//Callbacks
	selectHandler:null,
	closeHandler:null,
	
	//configuration
	minYear:1900,
	maxYear:2100,
	dateFormat:'%Y/%m/%d',
	
	//Dates
	date:new Date(),
	currentDateElement:null,
	
	//status
	shouldClose:false,
	isPopup:true,
	dateField:null,
	
  //----------------------------------------------------------------------------
  // Initialize
  //----------------------------------------------------------------------------

  initialize: function()
  {
      this.create()
  },
  
   update:function(date){
	  var calendar = this
	  var today = new Date()
	  var thisYear = today.getFullYear()
	  var thisMonth = today.getMonth()
	  var thisDay = today.getDate()
	  var month = date.getMonth()
	  var datatt = new Date(date)	  
	  var dayOfMonth = date.getDate()
	  
	  this.date = new Date(date)
	  
	  date.setDate(1)
	  date.setDate(-(date.getDay()) + 1)
	  
	  Element.getElementsBySelector(this.container,'tbody tr').each(
	  	function(row,i){
			var rowHasDays = false
			row.immediateDescendants().each(
				function(cell,j){
					var day = date.getDate()
					var dayOfWeek = date.getDay()
					var isCurrentMonth = (date.getMonth() == month)
					
					cell.className = ''
					cell.date = new Date(date)
					cell.update(day)
					
					if(!isCurrentMonth)
						cell.addClassName('otherDay')
					else
						rowHasDays = true
						
					// Ensure the current day is selected
					if (isCurrentMonth && day == dayOfMonth) {
					  cell.addClassName('selected')
					  calendar.currentDateElement = cell
					}
		
					// Today
					if (date.getFullYear() == thisYear && date.getMonth() == thisMonth && day == thisDay)
					  cell.addClassName('today')
		
					// Weekend
					if ([0, 6].indexOf(dayOfWeek) != -1)
					  cell.addClassName('weekend')
		
					// Set the date to tommorrow
					date.setDate(day + 1)	
				}
			)	
			!rowHasDays ? row.hide() : row.show()
		}
	  )
	  var selm = parseInt($('selMonth').value)
	  var sely = parseInt($('selMonthYear').value)
	  if(selm != date.getMonth() || sely != date.getFullYear()){
		this.displayMonthYear(datatt)
		}
	  
	  /*this.container.getElementsBySelector('td.title')[0].update(
	  	Calendar.month_names[month] + ' ' + this.date.getFullYear()
	  )*/
	},
	selmyChange:function(event){
		dDate = new Date($('selMonthYear').value, $('selMonth').selectedIndex, 1)
	    this.update(dDate)
	},
	displayMonthYear:function(dDate){
		var iYear = parseInt(dDate.getFullYear())
		var iMonth = parseInt(dDate.getMonth())
		$('selMonth').value = iYear
		$('selMonth').selectedIndex = iMonth
		var y = parseInt($('selMonthYear').options[19].value)+1
		if(dDate < (new Date($('selMonthYear').options[0].value,0,1,0,0,0))){
			$('selMonthYear').options.length = 0
			for(i = 0;i<$('selMonthYear').length+1;i++){
				$('selMonthYear').options[i].value = iYear
				iYear = iYear + 1
			}
		}
		if(dDate > new Date(y,0,0,0,0,0)){
			for(i = 19;i > -1;i--){
				$('selMonthYear').options[i].value = iYear
				iYear = iYear - 1
			}
		}
		$('selMonthYear').value = dDate.getFullYear()
		$('selMonthYear').selectedIndex = parseInt(y-dDate.getFullYear())
		var a = $('selMonth').options[parseInt($('selMonth').selectedIndex)]
		var b = $('selMonthYear').options[parseInt($('selMonthYear').selectedIndex)]
		//$('selMonthYear').options[parseInt(y-dDate.getFullYear())].setAttribute('selected','true')
	},
   //----------------------------------------------------------------------------
	  // Create/Draw the Calendar HTML Elements
  //---------------------------------------------------------------------------- 
    create:function(parent){
	  if(!parent){
			parent = document.getElementsByTagName('body')[0]
			this.isPopup = true  
		}else{ this.isPopup = false}
	  
	  var table = new Element('table')
	  
	  var thead = new Element('thead')
	  table.appendChild(thead)
	  
	  var row = new Element('tr')
	 /* var cell = new Element('td',{colSpan:2.5})
	  cell.addClassName('title')
	  row.appendChild(cell)
	  thead.appendChild(row)*/
	  
	  //row = new Element('tr')
	  //this._drawButtonCell(row, '&#x00ab;', 1, Calendar.NAV_PREVIOUS_YEAR)
      this._drawButtonCell(row, '&#x2039;', 1, Calendar.NAV_PREVIOUS_MONTH)
      //this._drawButtonCell(row, 'Today',    3, Calendar.NAV_TODAY)
	  var cell = new Element('td',{colspan:5})
	  var divmonth = new Element('div',{style:'float:left;width:38%'})
	  seltmonth = new Element('select',{style:'text-align:left',id:'selMonth'})
	  seltmonth.addClassName('DateSelect')
	  for(var i = 0;i<12;i++){
		  var optsel = new Element('option')
		  optsel.value=Calendar.MONTH_NAMES[i]
		  optsel.text = optsel.value
		  seltmonth.options.add(optsel)
		}
	  divmonth.appendChild(seltmonth)
	  cell.appendChild(divmonth)
	  row.appendChild(cell)
	  

	  //var cell = new Element('td',{colspan:2})
	  var divyear = new Element('div',{style:'float:right;width:62%'})
	  var divselover = new Element('div',{style:'overflow:hidden;width:50px;border-right: 1px solid #111;'})
	  divyear.addClassName('selyearstyle')
	  seltyear = new Element('select',{style:'text-align:left;float:left;width:70px',id:'selMonthYear'})
	  seltyear.addClassName('DateSelect')
	  var iScrap = this.date.getFullYear()-10
	  for(i=0;i<20;i++){
		  yearopt = new Element('Option')
		  yearopt.text = iScrap + i
		  yearopt.value = iScrap + i
		  //if(i = 10) yearopt.selectedIndex = 0
		 seltyear.options.add(yearopt)
		  }
	  divselover.appendChild(seltyear)
	  divyear.appendChild(divselover)
	  cell.appendChild(divyear)
	  row.appendChild(cell)
	  
      this._drawButtonCell(row, '&#x203a;', 1, Calendar.NAV_NEXT_MONTH)
      //this._drawButtonCell(row, '&#x00bb;', 1, Calendar.NAV_NEXT_YEAR)
	  thead.appendChild(row)
	  
	  //Day names
	  row = new Element('tr')
	  for(var i =0;i<7;++i){
		cell = new Element('th').update(Calendar.SHORT_DAY_NAMES[i])
		if(i == 0 || i == 6)
			cell.addClassName('weekend')
		row.appendChild(cell)  
	  }
	  thead.appendChild(row)
	  
	  //Calendar Days
	  var tbody = table.appendChild(new Element('tbody'))
	  for(i=6;i>0;--i){
		  row = tbody.appendChild(new Element('tr'))
		  row.addClassName('days')
		  for(var j=7;j>0; --j){
			cell = row.appendChild(new Element('td'))  
			cell.calendar = this
		  }
		  cell.calendar =this
	  }
	  this.container = new Element('div')
	  this.container.addClassName('calendar')
	  this.container.setStyle({position: 'absolute', display: 'none' })
	  this.container.addClassName('popup')
	  this.container.appendChild(table)
	  
	  parent.appendChild(this.container)	
	  
	  Event.observe(this.container,'mousedown',Calendar.handleMouseDownEvent)  
	  seltmonth.stopObserving('mousedown',Calendar.handleMouseDownEvent)
	  seltyear.stopObserving('mousedown',Calendar.handleMouseDownEvent)
	  seltmonth.observe('change',this.selmyChange.bind(this))
	  seltyear.observe('change',this.selmyChange.bind(this))

	  this.update(this.date)
	},
	_drawButtonCell:function(parent,text,colSpan,navAction){
		var cell = new Element('td')
		if(colSpan >1)cell.colSpan = colSpan
		cell.className = 'button'
		cell.calendar = this
		cell.navAction = navAction
		cell.innerHTML = text
		cell.unselectable = 'on'  //IE
		parent.appendChild(cell)
		return cell
	},
	callSelectHandler:function(){
		if(this.selectHandler)
		this.selectHandler(this,this.date.print(this.dateFormat))
	},
	callCloseHandler:function(){
		if(this.closeHandler)
			this.closeHandler(this)	
	},
	//------------------------------------------------------------------------------
    // Getters/Setters
    //------------------------------------------------------------------------------	
	setSelectHandler:function(selectHandler)
	{
		this.selectHandler = selectHandler
	},
	setCloseHandler:function(closeHandler)
	{
		this.closeHandler=closeHandler
	},
	setDate:function(date){
		if(!date.equalsTo(this.date))
			this.update(date)
	},
	setDateFormat:function(format){
		this.dateFormat = format
	},
	setDateField: function(field){
		this.dateField =$(field)
	},
	show:function(){
		this.container.show()
		window._popupCalendar = this
		Event.observe(document,'mousedown',Calendar._checkCalendar)
	},
	showAt:function(x,y){
		this.container.setStyle({ left: x + 'px', top: y + 'px' })
		this.show()
	},
	showAtElement:function(element){
		var pos = Position.cumulativeOffset(element)
		this.showAt(pos[0],pos[1])
	},
  //------------------------------------------------------------------------------
  // Calendar Display Functions
  //------------------------------------------------------------------------------
    hide:function(){
	 Event.stopObserving(document,'mousedown',Calendar._checkCalendar)
	 this.container.hide()
	},
	
	//
	parseDate:function(str,format){
		if(!format)
			format = this.dateFormat
		this.setDate(Date.parseDate(str,format))
	}
}

//globle object that remembers the calendar
window._popupCalendar = null
















//==============================================================================
//
// Date Object Patches
//
// This is pretty much untouched from the original. I really would like to get
// rid of these patches if at all possible and find a cleaner way of
// accomplishing the same things. It's a shame Prototype doesn't extend Date at
// all.
//
//==============================================================================

Date.DAYS_IN_MONTH = new Array(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
Date.SECOND        = 1000 /* milliseconds */
Date.MINUTE        = 60 * Date.SECOND
Date.HOUR          = 60 * Date.MINUTE
Date.DAY           = 24 * Date.HOUR
Date.WEEK          =  7 * Date.DAY

// Parses Date
Date.parseDate = function(str, fmt) {
  var today = new Date();
  var y     = 0;
  var m     = -1;
  var d     = 0;
  var a     = str.split(/\W+/);
  var b     = fmt.match(/%./g);
  var i     = 0, j = 0;
  var hr    = 0;
  var min   = 0;

  for (i = 0; i < a.length; ++i) {
    if (!a[i]) continue;
    switch (b[i]) {
      case "%d":
        d = parseInt(a[i], 10);
        break;
      case "%m":
        m = parseInt(a[i], 10) - 1;
        break;
      case "%Y":
        y = parseInt(a[i], 10);
        (y < 100) && (y += (y > 29) ? 1900 : 2000);
        break;
      case "%b":
      case "%B":
        for (j = 0; j < 12; ++j) {
          if (Calendar.MONTH_NAMES[j].substr(0, a[i].length).toLowerCase() == a[i].toLowerCase()) {
            m = j;
            break;
          }
        }
        break;
      case "%H":
      case "%I":
      case "%k":
      case "%l":
        hr = parseInt(a[i], 10);
        break;
      case "%P":
      case "%p":
        if (/pm/i.test(a[i]) && hr < 12)
          hr += 12;
        else if (/am/i.test(a[i]) && hr >= 12)
          hr -= 12;
        break;
      case "%M":
        min = parseInt(a[i], 10);
        break;
    }
  }
  if (isNaN(y)) y = today.getFullYear();
  if (isNaN(m)) m = today.getMonth();
  if (isNaN(d)) d = today.getDate();
  if (isNaN(hr)) hr = today.getHours();
  if (isNaN(min)) min = today.getMinutes();
  if (y != 0 && m != -1 && d != 0)
    return new Date(y, m, d, hr, min, 0);
  y = 0; m = -1; d = 0;
  for (i = 0; i < a.length; ++i) {
    if (a[i].search(/[a-zA-Z]+/) != -1) {
      var t = -1;
      for (j = 0; j < 12; ++j) {
        if (Calendar.MONTH_NAMES[j].substr(0, a[i].length).toLowerCase() == a[i].toLowerCase()) { t = j; break; }
      }
      if (t != -1) {
        if (m != -1) {
          d = m+1;
        }
        m = t;
      }
    } else if (parseInt(a[i], 10) <= 12 && m == -1) {
      m = a[i]-1;
    } else if (parseInt(a[i], 10) > 31 && y == 0) {
      y = parseInt(a[i], 10);
      (y < 100) && (y += (y > 29) ? 1900 : 2000);
    } else if (d == 0) {
      d = a[i];
    }
  }
  if (y == 0)
    y = today.getFullYear();
  if (m != -1 && d != 0)
    return new Date(y, m, d, hr, min, 0);
  return today;
};

// Returns the number of days in the current month
Date.prototype.getMonthDays = function(month) {
  var year = this.getFullYear()
  if (typeof month == "undefined")
    month = this.getMonth()
  if (((0 == (year % 4)) && ( (0 != (year % 100)) || (0 == (year % 400)))) && month == 1)
    return 29
  else
    return Date.DAYS_IN_MONTH[month]
};

// Returns the number of day in the year
Date.prototype.getDayOfYear = function() {
  var now = new Date(this.getFullYear(), this.getMonth(), this.getDate(), 0, 0, 0);
  var then = new Date(this.getFullYear(), 0, 0, 0, 0, 0);
  var time = now - then;
  return Math.floor(time / Date.DAY);
};

/** Returns the number of the week in year, as defined in ISO 8601. */
Date.prototype.getWeekNumber = function() {
  var d = new Date(this.getFullYear(), this.getMonth(), this.getDate(), 0, 0, 0);
  var DoW = d.getDay();
  d.setDate(d.getDate() - (DoW + 6) % 7 + 3); // Nearest Thu
  var ms = d.valueOf(); // GMT
  d.setMonth(0);
  d.setDate(4); // Thu in Week 1
  return Math.round((ms - d.valueOf()) / (7 * 864e5)) + 1;
};

/** Checks date and time equality */
Date.prototype.equalsTo = function(date) {
  return ((this.getFullYear() == date.getFullYear()) &&
   (this.getMonth() == date.getMonth()) &&
   (this.getDate() == date.getDate()) &&
   (this.getHours() == date.getHours()) &&
   (this.getMinutes() == date.getMinutes()));
};

/** Set only the year, month, date parts (keep existing time) */
Date.prototype.setDateOnly = function(date) {
  var tmp = new Date(date);
  this.setDate(1);
  this.setFullYear(tmp.getFullYear());
  this.setMonth(tmp.getMonth());
  this.setDate(tmp.getDate());
};

/** Prints the date in a string according to the given format. */
Date.prototype.print = function (str) {
  var m = this.getMonth();
  var d = this.getDate();
  var y = this.getFullYear();
  var wn = this.getWeekNumber();
  var w = this.getDay();
  var s = {};
  var hr = this.getHours();
  var pm = (hr >= 12);
  var ir = (pm) ? (hr - 12) : hr;
  var dy = this.getDayOfYear();
  if (ir == 0)
    ir = 12;
  var min = this.getMinutes();
  var sec = this.getSeconds();
  s["%a"] = Calendar.SHORT_DAY_NAMES[w]; // abbreviated weekday name [FIXME: I18N]
  s["%A"] = Calendar.DAY_NAMES[w]; // full weekday name
  s["%b"] = Calendar.SHORT_MONTH_NAMES[m]; // abbreviated month name [FIXME: I18N]
  s["%B"] = Calendar.MONTH_NAMES[m]; // full month name
  // FIXME: %c : preferred date and time representation for the current locale
  s["%C"] = 1 + Math.floor(y / 100); // the century number
  s["%d"] = (d < 10) ? ("0" + d) : d; // the day of the month (range 01 to 31)
  s["%e"] = d; // the day of the month (range 1 to 31)
  // FIXME: %D : american date style: %m/%d/%y
  // FIXME: %E, %F, %G, %g, %h (man strftime)
  s["%H"] = (hr < 10) ? ("0" + hr) : hr; // hour, range 00 to 23 (24h format)
  s["%I"] = (ir < 10) ? ("0" + ir) : ir; // hour, range 01 to 12 (12h format)
  s["%j"] = (dy < 100) ? ((dy < 10) ? ("00" + dy) : ("0" + dy)) : dy; // day of the year (range 001 to 366)
  s["%k"] = hr;   // hour, range 0 to 23 (24h format)
  s["%l"] = ir;   // hour, range 1 to 12 (12h format)
  s["%m"] = (m < 9) ? ("0" + (1+m)) : (1+m); // month, range 01 to 12
  s["%M"] = (min < 10) ? ("0" + min) : min; // minute, range 00 to 59
  s["%n"] = "\n";   // a newline character
  s["%p"] = pm ? "PM" : "AM";
  s["%P"] = pm ? "pm" : "am";
  // FIXME: %r : the time in am/pm notation %I:%M:%S %p
  // FIXME: %R : the time in 24-hour notation %H:%M
  s["%s"] = Math.floor(this.getTime() / 1000);
  s["%S"] = (sec < 10) ? ("0" + sec) : sec; // seconds, range 00 to 59
  s["%t"] = "\t";   // a tab character
  // FIXME: %T : the time in 24-hour notation (%H:%M:%S)
  s["%U"] = s["%W"] = s["%V"] = (wn < 10) ? ("0" + wn) : wn;
  s["%u"] = w + 1;  // the day of the week (range 1 to 7, 1 = MON)
  s["%w"] = w;    // the day of the week (range 0 to 6, 0 = SUN)
  // FIXME: %x : preferred date representation for the current locale without the time
  // FIXME: %X : preferred time representation for the current locale without the date
  s["%y"] = ('' + y).substr(2, 2); // year without the century (range 00 to 99)
  s["%Y"] = y;    // year with the century
  s["%%"] = "%";    // a literal '%' character

  return str.gsub(/%./, function(match) { return s[match] || match });
};

Date.prototype.__msh_oldSetFullYear = Date.prototype.setFullYear;
Date.prototype.setFullYear = function(y) {
  var d = new Date(this);
  d.__msh_oldSetFullYear(y);
  if (d.getMonth() != this.getMonth())
    this.setDate(28);
  this.__msh_oldSetFullYear(y);
}
