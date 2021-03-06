/*******************************************************************
* record-vu.p
* version: 1.0
* Author: Tom B
* 16-Feb-2014
*
* Description:
* This program provides a method of retrieving all record data for any table 
* and key with the viewrecord procedure, it also provides a method to update
* any field providing the user has a unique key, through the updaterecord
* procedure. The viewrecord procedure outputs the record details to an output 
* file, the updaterecord procedure updates the specified field and generates an 
* audit file of the data changed (including the old value). 
*
* Directions for use:
* The usage should be easy to follow from the messages to the user. If you 
* miss-type any entry or receive a runtime datatype error (due to using the 
* wrong datatype when updating a field) it is best practice to exit and launch 
* the program again. Due to the dynamic nature of the program the on screen 
* '��fiel' are re-used when entering the values for the key fields, the 
* current field is displayed as a message to the user. Also, you can quickly 
* check the current value of a specific field by using the updaterecord 
* procedure but exiting prior to making any change to the field. If you use 
* the viewrecord procedure, remove the output file after use.
*
* > Enter the table required and specify whether to update or view.
* > Enter the key to use, available keys are displayed in a message, for 
*   updaterecord this can only be a unique key.
* > All fields of the selected key are displayed in a message.
* > Enter the values for the fields of the key, the current field is displayed
    in a message.
* > Viewrecord finishes here and will generate the output file.
* > For updaterecord, enter the field you wish to update
* > A confirmation screen is displayed, verify details and enter yes to 
    continue.
* > The current field value is displayed and updatable.
* > Enter the required value, the change is made and audit file is generated.
*
* Notes:
* The program leverages accessibility to table meta data and dynamic queries 
* (available in OpenEdge 9+). Working in this fashion makes it very difficult 
* to label widgets on screen, which is why so much of the information to the 
* used is done via message. When querying the table meta data, the table type 
* is hardcoded to 'T' so thetables cannot be queried, for security. 
* Finally, all fields of a key are required and cannot be skipped.
********************************************************************/      

/*Launcher*/
def var w-choice as log init false label "View/Update".
def var w-t as char format "x(25)" label "Table".

message "Enter table".
update w-t with frame f0 title "Record-VU".
message "Yes to update specific field, no to view all fields".
update w-choice with frame f0.
if w-choice then run updaterecord(w-t).
else run viewrecord(w-t).

/*viewrecord procedure*/ 
procedure viewrecord: 

    def input parameter w-table as char no-undo.
        
    def var w-tablerecid as int.
    def var w-nokeyeles as int.
    def var w-keylist as char label "Available indices" format "x(100)".
    def var w-keychoice as char label "Key" format "x(25)".
    def var w-keystring as char format "x(50)" init "".
    def var w-keyarray as char extent 10 no-undo.
    def var w-sstrings as char extent 10 format "x(50)"label "Value" no-undo.
            
    /*counters*/
    def var w-i as int init 1.
    def var w-counter as int init 1.
    def var w-iextentcounter as int.
    
    find _file where _file._file-name = w-table
                  and _file._tbl-type = "T" no-error.
   
    if avail _file then do:
        assign w-tablerecid = recid(_file).
    end.
    else do:
        message "Table" w-table "does no exist".
        message "Exiting...".
        return.
    end.
        
    for each _index where _index._file-recid = recid(_file) 
        no-lock by _index._unique descending:
        w-keylist = w-keylist + _index._index-name + ", ".
    end.

    message "Available keys (unique(s) first): "w-keylist.
    
    update w-keychoice with frame f1.
    if w-keychoice = "" or w-keychoice = ? then do:
        message "Key not specified".
        message "Exitting...".
        return.
    end.    
        
    find _index where _index._file-recid = recid(_file)
                  and _index._index-name = w-keychoice.
    assign w-nokeyeles = _index._num-comp.                       
        
    for each _index-field where _index-field._index-recid = recid(_index) 
        no-lock:
        find _field where recid(_field) = _index-field._field-recid.
        w-keyarray[w-counter] = _field._field-name.
        assign w-counter = w-counter + 1.
        w-keystring = w-keystring + _field._field-name + ", ".
    end.
    
    message "Key: " w-keychoice " Fields: " w-keystring.  
     
    do w-i = 1 to w-nokeyeles:
        message "Field: " w-keyarray[w-i].
        put w-keyarray[w-i] skip.
        form w-sstrings[w-i] with frame f1.
        
        /*Tried to do some labelling here, doesn't play ball
        keeping as a syntax reminder
        w-sstrings[w-i]:label in frame f1 = w-keyarray[w-i].
        frame f1 w-sstrings[w-i]:label = w-keyarray[w-i].*/
        
        update w-sstrings[w-i] with frame f1.
    end.
          
    def var w-querycrit as char format "x(200)".
    assign w-querycrit = "for each " + w-table + " where ".          
    do w-i = 1 to w-nokeyeles:
        if w-i = 1 then do:
              w-querycrit = w-querycrit + w-keyarray[w-i] + " = " + "'" 
              + w-sstrings[w-i] + "'".
        end.
        else do:
             w-querycrit = w-querycrit + " and " + w-keyarray[w-i] 
             + " = " + "'" +  w-sstrings[w-i] + "'".
        end.
    end.
    
    /*Start writing to output*/
    def var w-filename as char init "RecordView".
    output to value(w-filename + "-" + w-table + "-" + string(time,"hh:mm:ss")
    + ".txt"). 
    put "Record results for query:" skip.
    put w-querycrit skip.               
  
    /*Start of the dynamic query work*/
    def var qh as handle no-undo.
    def var bh as handle no-undo.
    def var fh as handle no-undo.
    create buffer bh for table w-table.
    create query qh.
    qh:set-buffers(bh).
    qh:query-prepare(string(w-querycrit)).
    qh:query-open().

    do transaction:
        repeat:
            qh:get-next( no-lock ).
            if qh:query-off-end then leave.
            put skip skip(2)"********************************************".
            put skip "Record:".
            put skip "********************************************" skip.
            do w-i = 1 to bh:NUM-FIELDS:
                fh = bh:buffer-field(w-i).
                if fh:extent = 0 then do:
                    put fh:name format "x(30)" fh:buffer-value format "x(80)"
                    skip.
                end.
                else do:
                    do w-iextentcounter = 1 to fh:extent:
                        put fh:name format "x(30)"
                        fh:buffer-value[w-iextentcounter] format "x(80)" skip.
                    end.
                end.
            end.
        end.        
    end.
    
    /*Tidy up*/    
    delete object bh.
    delete object qh.
    output close.
    return.    
end.               

/*The update procedure*/
procedure updaterecord: 

    def input parameter w-table as char no-undo.
    
    def var w-tablerecid as int.
    def var w-nokeyeles as int. 
    def var w-keylist as char label "Available indices" format "x(100)".
    def var w-keychoice as char label "Key" format "x(25)".
    def var w-keystring as char format "x(50)" init "".
    def var w-filename as char init "RecordUpdate".
    def var w-field as char format "x(50)" label "Field" no-undo.
    def var w-updatevalue as char format "x(25)" label "Value".
    def var w-oldval as char format "x(25)".    
    def var w-allkeystring as char format "x(50)".
    def var w-allvalstring as char format "x(50)".
    def var w-keyarray as char extent 10 no-undo.
    def var w-sstrings as char extent 10 format "x(50)"label "Value" no-undo.
    def var w-isarray as log init false.
    def var w-continue as log init false. 
        
    /*counters*/
    def var w-counter as int init 1.
    def var w-i as int init 1.
    /*def var w-iextentcounter as int.*/
    def var w-aele as int label "Array element".
        
    
    find _file where _file._file-name = w-table
        and _file._tbl-type = "T" no-error.
   
    if avail _file then do:
        assign w-tablerecid = recid(_file).
    end.
    else do:
        message "Table" w-table "does no exist".
        message "Exiting...".
        return.
    end.
        
    for each _index where _index._file-recid = recid(_file)
        and _index._unique = true no-lock 
        by _index._unique descending:
        w-keylist = w-keylist + _index._index-name + ", ".
    end.

    message "Unique key(s): "w-keylist.
    
    update w-keychoice with frame f1.
    if w-keychoice = "" or w-keychoice = ? then do:
        message "Key not specified".
        message "Exitting...".
        return.
    end.    
        
    find _index where _index._file-recid = recid(_file)
        and _index._index-name = w-keychoice.
    
    if _index._unique <> true then do:
        message "Stop trying to use a non-unique key".
        message "Exitting...".
        return.
    end.                     
    
    assign w-nokeyeles = _index._num-comp.                       
        
    for each _index-field where _index-field._index-recid = recid(_index) 
        no-lock:
        
        find _field where recid(_field) = _index-field._field-recid.
        w-keyarray[w-counter] = _field._field-name.
        assign w-counter = w-counter + 1.
        w-keystring = w-keystring + _field._field-name + ", ".
    end.
    
    message "Key: " w-keychoice " Fields: " w-keystring.  
     
    do w-i = 1 to w-nokeyeles:
        message "Field: " w-keyarray[w-i].
        put w-keyarray[w-i] skip.
        form w-sstrings[w-i] with frame f1.
        update w-sstrings[w-i] with frame f1.
    end.
    
    /*getting the field and value*/
    message "Specify which field you wish to update".
    update w-field with frame f2.
    
    /*check field is valid*/
    find _field where _field._file-recid = w-tablerecid
        and _field._field-name = w-field no-error.
    
    if not avail _field then do:
        message "Invalid field - exiting...".
        leave.
    end.         
    
    /*Build strings of key fields and value for display only*/  
    do w-i = 1 to w-nokeyeles:
        w-allkeystring = w-allkeystring + w-keyarray[w-i] + ", ".
        w-allvalstring = w-allvalstring + w-sstrings[w-i] + ", ".
    end.    
    
    display "You wish to update" skip trim(w-field, " ") no-label " on "
    w-table format "x(25)" no-label skip "for" skip w-allkeystring no-label 
    skip w-allvalstring no-label skip with frame f9.
    display skip(2) "Continue: " w-continue no-label with frame f9.
    message "Enter yes to continue". 
    update w-continue with frame f9.
    if w-continue <> true then return.
        
    def var w-querycrit as char format "x(200)".
    assign w-querycrit = "for each " + w-table + " where ".          
    do w-i = 1 to w-nokeyeles:
        if w-i = 1 then do:
              w-querycrit = w-querycrit + w-keyarray[w-i] + " = " + "'" 
              + w-sstrings[w-i] + "'".
        end.
        else do:
             w-querycrit = w-querycrit + " and " + w-keyarray[w-i] 
             + " = " + "'" +  w-sstrings[w-i] + "'".
        end.
    end.
         
    /*Start of the dynamic query work*/
    def var qh as handle no-undo.
    def var bh as handle no-undo.
    def var fh as handle no-undo.
    def var oldvalh as handle no-undo.
    
    create buffer bh for table w-table.
    create query qh.
    qh:set-buffers(bh).
    qh:query-prepare(string(w-querycrit)).
    qh:query-open().
    do transaction:
        qh:get-next( exclusive-lock ).
        if qh:query-off-end then do:
            message "No records found".
            leave.
        end.
            
        fh = bh:buffer-field(w-field).
        message "field type: " + fh:data-type.
        
        if fh:extent = 0 then do:
            w-oldval = fh:buffer-value.
            w-updatevalue = fh:buffer-value. 
            update w-updatevalue with frame f4.
            fh:buffer-value = w-updatevalue.
        end.
        
        else do: /*array field*/
            w-isarray = true.
            update w-aele with frame f5.
            w-oldval = fh:buffer-value(w-aele).
            w-updatevalue = fh:buffer-value(w-aele).
            update w-updatevalue with frame f6.
            fh:buffer-value(w-aele) = w-updatevalue.
        end.
        message "Field updated, audit file generated".
    end.
    
     /*Start writing to output*/
    output to value(w-filename + "-" + w-table + "-" + string(time,"hh:mm:ss") 
    + ".txt").
    
    put "**************************************" skip.
    put "Record Update Audit" skip.
    put "**************************************" skip.
    put "Date/Time: " string(now) + string(time,"hh:mm:ss") format "x(19)" skip.
    put "Query: " skip.
    put w-querycrit skip.
    put "Field: " trim(w-field). 
    if w-isarray then put "[" (w-aele) format "ZZ" "]".
    put skip "Field datatype: " fh:data-type format "x(20)" skip.
    put "Previous value: " + w-oldval format "x(40)" skip.
    put "New value: " + w-updatevalue format "x(40)" skip.
     
    /*Tidy up*/    
    delete object bh.
    delete object qh.
    output close.
return.    
end.               
