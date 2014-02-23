/*******************************************************************
* record-view.p
* Author: Tom B
* 17-Feb-2014

* Description:
* This program provides a method of retrieving all record data for any table 
* and key, the procedure sends the record details to an output file. The 
* output file is name 'Record-View-<table>-<current-time>.txt
*
* Directions for use:
* The usage should be easy to follow from the messages to the user. If you 
* miss-type any entry it is best practice to exit and launch the program again.
* Due to the dynamic nature of the program the on screen 
* 'fields' are re-used when entering the values for the key elements, the 
* current field is displayed as a message to the user. Remember to remove 
* the output file after use.
*
* > Enter the table required.
* > Enter the key to use, available keys are displayed in a message.
* > All fields of the selected key are displayed in a message.
* > Enter the values for the fields of the key, the current field is displayed
    in a message.
* > The proceedure will complete, view the output file in the default directory.
*
* Notes:
* The program leverages accessibility to table meta data and dynamic queries 
* (available in OpenEdge 9+). Working in this fashion makes it very difficult 
* to label widgets on screen, which is why so much of the information to the 
* used is done via message. When querying the table meta data, the table type 
* is hardcoded to 'T' so thetables cannot be queried, for security. 
* Finally, all fields of a key are required and cannot be skipped.
********************************************************************/      

def var w-t as char format "x(25)" label "Table".
message "Enter table".
update w-t with frame f0 title "Record-view".
run viewrecord(w-t).
 
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