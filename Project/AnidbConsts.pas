unit AnidbConsts;

interface

//File states
const
  STATE_UNKNOWN     = 0;
  STATE_HDD         = 1;
  STATE_CD          = 2;
  STATE_DELETED     = 3;

const
// POSITIVE 2XX

	LOGIN_ACCEPTED				    = 200; //a
	LOGIN_ACCEPTED_NEW_VER		= 201; //a
	LOGGED_OUT		        		= 203; //a
	RESOURCE				          = 205; //d
	STATS				            	= 206; //b
	TOP	               				= 207; //b
	UPTIME			          		= 208; //b
	ENCRYPTION_ENABLED		  	= 209; //c

	MYLIST_ENTRY_ADDED		    = 210; //a
	MYLIST_ENTRY_DELETED			= 211; //a

	ADDED_FILE			        	= 214; //e
	ADDED_STREAM				      = 215; //e

	ENCODING_CHANGED			    = 219; //c

	C_FILE  	            		= 220; //a
	MYLIST				          	= 221; //a
	MYLIST_STATS		      		= 222; //b

	ANIME		            			= 230; //b
	ANIME_BEST_MATCH	    		= 231; //b
	RANDOMANIME			        	= 232; //b

	EPISODE			          		= 240; //b
	PRODUCER			          	= 245; //b
	GROUP				            	= 250; //b

	BUDDY_LIST			        	= 253; //c
	BUDDY_STATE			         	= 254; //c
	BUDDY_ADDED			        	= 255; //c
	BUDDY_DELETED			       	= 256; //c
	BUDDY_ACCEPTED			    	= 257; //c
	BUDDY_DENIED			      	= 258; //c

	VOTED			          	  	= 260; //b
	VOTE_FOUND	        			= 261; //b
	VOTE_UPDATED			      	= 262; //b
	VOTE_REVOKED			      	= 263; //b

	NOTIFICATION_ENABLED			= 270; //a
	NOTIFICATION_NOTIFY		  	= 271; //a
	NOTIFICATION_MESSAGE			= 272; //a
	NOTIFICATION_BUDDY		  	= 273; //c
	NOTIFICATION_SHUTDOWN			= 274; //c
	PUSHACK_CONFIRMED		    	= 280; //a
	NOTIFYACK_SUCCESSFUL_M		= 281; //a
	NOTIFYACK_SUCCESSFUL_N		= 282; //a
	NOTIFICATION			      	= 290; //a
	NOTIFYLIST			        	= 291; //a
	NOTIFYGET_MESSAGE			    = 292; //a
	NOTIFYGET_NOTIFY			    = 293; //a

	SENDMSG_SUCCESSFUL	  		= 294; //a
	USER			            		= 295; //d

	// AFFIRMATIVE/NEGATIVE 3XX

	PONG		            			= 300; //a
	AUTHPONG			          	= 301; //c
	NO_SUCH_RESOURCE		      = 305; //d
	API_PASSWORD_NOT_DEFINED 	= 309; //c

 	FILE_ALREADY_IN_MYLIST	 	= 310; //a
	MYLIST_ENTRY_EDITED		  	= 311; //a
	MULTIPLE_MYLIST_ENTRIES		= 312; //e

	SIZE_HASH_EXISTS		    	= 314; //c
	INVALID_DATA				      = 315; //c
	STREAMNOID_USED			    	= 316; //c

	NO_SUCH_FILE		      		= 320; //a
	NO_SUCH_ENTRY			      	= 321; //a
	MULTIPLE_FILES_FOUND			= 322; //b

	NO_SUCH_ANIME			      	= 330; //b
	NO_SUCH_EPISODE			    	= 340; //b
	NO_SUCH_PRODUCER		    	= 345; //b
	NO_SUCH_GROUP				      = 350; //b

	BUDDY_ALREADY_ADDED		  	= 355; //c
	NO_SUCH_BUDDY			      	= 356; //c
	BUDDY_ALREADY_ACCEPTED	  = 357; //c
	BUDDY_ALREADY_DENIED			= 358; //c

	NO_SUCH_VOTE		      		= 360; //b
	INVALID_VOTE_TYPE		    	= 361; //b
	INVALID_VOTE_VALUE		  	= 362; //b
	PERMVOTE_NOT_ALLOWED			= 363; //b
	ALREADY_PERMVOTED			    = 364; //b

	NOTIFICATION_DISABLED			= 370; //a
	NO_SUCH_PACKET_PENDING		= 380; //a
	NO_SUCH_ENTRY_M			     	= 381; //a
	NO_SUCH_ENTRY_N			    	= 382; //a

	NO_SUCH_MESSAGE			    	= 392; //a
	NO_SUCH_NOTIFY		    		= 393; //a
	NO_SUCH_USER		      		= 394; //a


	// NEGATIVE 4XX


	NOT_LOGGED_IN			      	= 403; //a

	NO_SUCH_MYLIST_FILE		  	= 410; //a
	NO_SUCH_MYLIST_ENTRY			= 411; //a


	// CLIENT SIDE FAILURE 5XX


	LOGIN_FAILED			      	= 500; //a
	LOGIN_FIRST			        	= 501; //a
	ACCESS_DENIED			      	= 502; //a
	CLIENT_VERSION_OUTDATED		= 503; //a
	CLIENT_BANNED				      = 504; //a
	ILLEGAL_INPUT_OR_ACCESS_DENIED		= 505; //a
	INVALID_SESSION				    = 506; //a
	NO_SUCH_ENCRYPTION_TYPE		= 509; //c
	ENCODING_NOT_SUPPORTED		= 519; //c

	BANNED			          		= 555; //a
	UNKNOWN_COMMAND			    	= 598; //a


	// SERVER SIDE FAILURE 6XX


	INTERNAL_SERVER_ERROR			= 600; //a
	ANIDB_OUT_OF_SERVICE			= 601; //a
	SERVER_BUSY			        	= 602; //d
	API_VIOLATION			      	= 666; //a

type
 //File information that is stored in Anidb
  TAnidbFileState = record
    State: integer;
    State_set: boolean;
    Viewed: boolean;
    Viewed_set: boolean;
    ViewDate: TDatetime;
    ViewDate_set: boolean;
    Source: string;
    Source_set: boolean;
    Storage: string;
    Storage_set: boolean;
    Other: string;
    Other_set: boolean;
  end;

 //True if at least one field is set
function AfsSomethingIsSet(afs: TAnidbFileState): boolean;

//Updates afs fields with new data (only the parts that were changed)
procedure AfsUpdate(var afs: TAnidbFileState; newData: TAnidbFileState);

implementation

function AfsSomethingIsSet(afs: TAnidbFileState): boolean;
begin
  Result := afs.State_set
    or afs.Viewed_set
    or afs.ViewDate_set
    or afs.Source_set
    or afs.Storage_set
    or afs.Other_set;
end;

procedure AfsUpdate(var afs: TAnidbFileState; newData: TAnidbFileState);
begin
  if newData.State_set then begin
    afs.State := newData.State;
    afs.State_set := true;
  end;

  if newData.Viewed_set then begin
    afs.Viewed := newData.Viewed;
    afs.Viewed_set := true;
  end;

  if newData.ViewDate_set then begin
    afs.ViewDate := newData.ViewDate;
    afs.ViewDate_set := true;
  end;

  if newData.Source_set then begin
    afs.Source := newData.Source;
    afs.Source_set := true;
  end;

  if newData.Storage_set then begin
    afs.Storage := newData.Storage;
    afs.Storage_set := true;
  end;

  if newData.Other_set then begin
    afs.Other := newData.Other;
    afs.Other_set := true;
  end;
end;

end.
