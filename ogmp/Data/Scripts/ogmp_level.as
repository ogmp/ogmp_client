const int _movement_state = 0; // character is moving on the ground
const int _ground_state = 1; // character has fallen down or is raising up, ATM ragdolls handle most of this
const int _attack_state = 2; // character is performing an attack
const int _hit_reaction_state = 3; // character was hit or dealt damage to and has to react to it in some manner
const int _ragdoll_state = 4; // character is falling in ragdoll mode

bool debug = false;
bool has_client_connect_gui = false;
bool has_chat_gui = false;
bool showing_playerlist;
string client_uid;
string welcome_message;
string username;
string level_name;
string server_address;
bool connected_to_server = false;
float frequency = 1.0f;
float delay = 1.0f;
uint32 client_connect_id;
uint32 chat_id;
uint32 playerlist_id;
bool showing_chat_input = false;
array<MovementObject@> remote_players;

void UpdateOGMP() {
	CheckKeys();
	HandleConnection();
	HandleChat();	
	DrawUsernames();
	SendUpdate();
}

void CheckKeys() {
	if(!has_gui && !has_client_connect_gui && GetInputPressed(controller_id, "f12") && GetPlayerCharacterID() != -1) {
		// If the user already has a client connect window we have to destroy it first.
		if(client_connect_id > 0) {
			gui.RemoveGUI(client_connect_id);
		}

		// This closes the current connection, so this has to be handled.
		if(connected_to_server) {
			Disconnect();
		}

		// Now we can create the html document. This is the object that will actually connect to the server.
		client_connect_id = gui.AddGUI("gamemenu", "ClientConnect\\clientconnect.html", int(GetScreenWidth()/1.5f), 500, 0);
		has_client_connect_gui = true;
		gui.Execute(client_connect_id,"level = \""+level_name+"\";");

		// Send current player position to client connect document for spawn.
		int player_id = GetPlayerCharacterID();

		if(player_id == -1) {
			return;
		}

		MovementObject@ char = ReadCharacter(player_id);
		gui.Execute(client_connect_id,"posx = "+char.position.x+";");
		gui.Execute(client_connect_id,"posy = "+char.position.y+";");
		gui.Execute(client_connect_id,"posz = "+char.position.z+";");
	}

	if(connected_to_server) {
		if(GetInputPressed(controller_id, "return")) {
			has_chat_gui = !has_chat_gui;
			gui.Execute(chat_id,"toggleChat();");
		}

		if(GetInputDown(controller_id, "f11")) {
			if(!showing_playerlist) {
				playerlist_id = gui.AddGUI("gamemenu","ClientConnect\\playerlist.html",GetScreenWidth()/2,GetScreenHeight()/2,0);
				gui.Execute(playerlist_id,"server_address = \""+server_address+"\"");

				showing_playerlist = true;
			}		
		}

		if(showing_playerlist && !GetInputDown(controller_id, "f11")) {
			gui.RemoveGUI(playerlist_id);
			showing_playerlist = false;
		}

		if(GetInputPressed(controller_id, "k")) {
			MovementObject@ char = ReadCharacter(0);

			if((char.GetFloatVar("permanent_health") > 0) && (char.GetFloatVar("temp_health") > 0)) {
				string message = "type=SavePosition" + "&uid=" + client_uid;
				PrintDebug(message + "\n");
				gui.Execute(client_connect_id,"sendUpdate(\""+message+"\")");
			}
		}

		if(GetInputPressed(controller_id, "l")) {
			MovementObject@ char = ReadCharacter(0);

			if((char.GetFloatVar("permanent_health") > 0) && (char.GetFloatVar("temp_health") > 0)) {
				string message = "type=LoadPosition" + "&uid=" + client_uid;
				PrintDebug(message + "\n");
				gui.Execute(client_connect_id,"sendUpdate(\""+message+"\")");
			}
		}
	}
}

void HandleConnection() {
	if(has_client_connect_gui || connected_to_server) {
		string callback = gui.GetCallback(client_connect_id);

		while(callback != "") {
			JSON connectionData;
			connectionData.parseString(callback);
			JSONValue connectionDataRoot = connectionData.getRoot();

			//If there is a callback the gui should be closed.
			if(has_client_connect_gui) {
				PrintDebug("Disabling has client connect gui\n");
				has_client_connect_gui = false;
			}

			if(connectionDataRoot["command"].asString() == "closeWindow") {
				callback = gui.GetCallback(client_connect_id);
				continue;
			}

			int updates_size = connectionDataRoot["updates"].size();
			for (int a = 0; a < updates_size; a++) {
				JSONValue update = connectionDataRoot["updates"][a];
				string type = update["type"].asString();

				if(type == "SignOn") {
					string team = update["team"].asString();
					string character_dir = update["character"].asString();

					client_uid = update["uid"].asString();
					frequency = update["refr"].asString();
					welcome_message = update["welcome_message"].asString();
					username = update["username"].asString();
					server_address = update["server"].asString();

					connected_to_server = true;

					int player_id = GetPlayerCharacterID();

					if(player_id == -1) {
						continue;
					}

					MovementObject@ char = ReadCharacter(player_id);
					char.Execute("MPIsConnected = true;");
					
					// Chat
					gui.Execute(client_connect_id,"connectSuccessful()");
					PrintDebug("Successfully connected to server. UID: " + client_uid + "\n");

					if(chat_id <= 0) {
						chat_id = gui.AddGUI("gamemenu","ClientConnect\\chat.html",400,400,0);

						gui.MoveTo(chat_id,GetScreenWidth()-400,GetScreenHeight()-400);
					}

					gui.Execute(chat_id,"addChat('System', 'Successfully connected to server.',true)");

					string filtered = join( welcome_message.split( "\"" ), "" );
					gui.Execute(chat_id,"addChat('System','Server message: "+filtered+"',true)");

					gui.Execute(chat_id,"name = '"+username+"';");

					// Prepare other players or remove them.
					array<int> delete_chars;

					for(int i=0; i<GetNumCharacters(); ++i) {
						PrintDebug("Adding player " + i + ": " + username + "\n");
						
						MovementObject@ other_char = ReadCharacter(i);
						if(other_char.controlled) {
							PrintDebug("Player is controlled\n");
							
							Object@ char_obj = ReadObjectFromID(char.GetID());
							ScriptParams@ params = char_obj.GetScriptParams();

							if(params.HasParam("Name")) {
								params.SetString("Name", username);
							} else{
								params.AddString("Name", username);
							}
							if(params.HasParam("Teams")) {
								params.SetString("Teams", team);
							} else{
								params.AddString("Teams", team);
							}
							other_char.Execute("SwitchCharacter(\"Data/Characters/" + character_dir + ".xml\");");
						} else{
							delete_chars.insertLast(other_char.GetID());
						}
					}

					int num = delete_chars.size();
					for(int i = 0;i<num;i++) {
						PrintDebug("Delete character" + delete_chars[i] + "\n");
						
						DeleteObjectID(delete_chars[i]);
					}

					//Every known character needs to be removed or else the situationawareness script will check the nonexisting movementobjects
					MovementObject@ temp_char = ReadCharacter(0);
					temp_char.Execute("situation.clear();");
				} else if(type == "Timeout") {
					PrintDebug("Timeout\n");
					Disconnect();
				} else if(type == "SpawnCharacter") {
					string new_player_username = update["username"].asString();
					string new_player_char_dir = "Data/Characters/ogmp/" + update["character"].asString() + ".xml";
					string new_player_team = update["team"].asString();
					float new_player_posx = update["posx"].asFloat();
					float new_player_posy = update["posy"].asFloat();
					float new_player_posz = update["posz"].asFloat();

					//Then the new player is spawned 
					int new_player_id = CreateObject(new_player_char_dir); // TODO: check this out

					//The newly created character is always the last item in the GetNumCharacters list.
					MovementObject@ new_char = ReadCharacter(GetNumCharacters()-1);
					new_char.Execute("MPIsConnected = true;");

					//Set spawn position.
					new_char.position.x = new_player_posx;
					new_char.position.y = new_player_posy;
					new_char.position.z = new_player_posz;

					//Just in case stop any movement.
					new_char.velocity = vec3(0);

					//Reset animations to avoid long arms.
					new_char.Execute("ResetSecondaryAnimation();");

					//This new character is added to our own remote_player list so we can keep track of it.
					remote_players.insertLast(new_char);

					//The paramters are attached to the Object for some reason and not the MovementObject.
					Object@ char_obj = ReadObjectFromID(new_char.GetID());
					ScriptParams@ params = char_obj.GetScriptParams();

					//A new Name parameter is added. This way we can later delete and update the right MovementObject by name.
					params.AddString("Name", new_player_username);

					if(params.HasParam("Teams")) {
						params.SetString("Teams", new_player_team);
					} else{
						params.AddString("Teams", new_player_team);
					}
					
					PrintDebug("Adding character with name: " + new_player_username + " and char dir : " + new_player_char_dir + " and team " + new_player_team + "\n");
				} else if(type == "RemoveCharacter") {
					string remove_name = update["username"].asString();

					//Loop through the remote_players list to find the character with the correct name.
					int remove_id = -1;
					int num_chars = remote_players.size();
					for(int i = 0; i< num_chars; i++) {
						MovementObject@ temp_char = remote_players[i];
						Object@ char_obj = ReadObjectFromID(temp_char.GetID());
						ScriptParams@ params = char_obj.GetScriptParams();
						if(params.HasParam("Name")) {
							string name_str = params.GetString("Name");
							if(remove_name == name_str) {
								//If the character with the right name is found the object is deleted and we remove the MovementObject from the remote_players list.
								remove_id = temp_char.GetID(); // TODO: check this out
								remote_players.removeAt(i);
								
								// There can only be one, stop. Could crash otherwise.
								break;
							}
						}
					}
					//If the character is not found the script will just skip it.
					if(remove_id != -1) {
						PrintDebug("remove player id: " + remove_id + " with name " + remove_name + "\n");
						DeleteObjectID(remove_id);
					}
					//Every character needs the situation updated or else they will check for the character we just removed.
					num_chars = GetNumCharacters();
					for(int i=0; i<num_chars; ++i) {
						MovementObject@ temp_char = ReadCharacter(i);
						temp_char.Execute("situation.clear();");
					}
				} else if(type == "Update") {
					string remote_player_name = update["username"].asString();
					float remote_player_posx = update["posx"].asFloat();
					float remote_player_posy = update["posy"].asFloat();
					float remote_player_posz = update["posz"].asFloat();
					float remote_player_dirx = update["dirx"].asFloat();
					float remote_player_dirz = update["dirz"].asFloat();
					float remote_player_blood_damage = update["blood_damage"].asFloat();
					float remote_player_blood_health = update["blood_health"].asFloat();
					float remote_player_block_health = update["block_health"].asFloat();
					float remote_player_temp_health = update["temp_health"].asFloat();
					float remote_player_permanent_health = update["permanent_health"].asFloat();
					bool remote_player_jump = update["jump"].asBool();
					bool remote_player_crouch = update["crouch"].asBool();
					bool remote_player_attack = update["attack"].asBool();
					bool remote_player_grab = update["grab"].asBool();
					bool remote_player_item = update["item"].asBool();
					bool remote_player_drop = update["drop"].asBool();
					bool remote_player_roll = update["roll"].asBool();
					bool remote_player_jumpoffwall = update["offwall"].asBool();
					bool remote_player_activeblock = update["activeblock"].asBool();
					int remote_player_knocked_out = update["knocked_out"].asInt();
					int remote_player_lives = update["lives"].asInt();
					float remote_player_blood_amount = update["blood_amount"].asFloat();
					float remote_player_recovery_time = update["recovery_time"].asFloat();
					float remote_player_roll_recovery_time = update["roll_recovery_time"].asFloat();
					int remote_player_ragdoll_type = update["ragdoll_type"].asInt();
					bool remote_player_remove_blood = update["remove_blood"].asBool();
					bool remote_player_cut_throat = update["cut_throat"].asBool();
					bool remote_player_cut_torso = update["cut_torso"].asBool();
					int remote_player_state = update["state"].asInt();

					int remote_player_id = -1;
					int num_players = remote_players.size();
					for(int i = 0; i< num_players; i++) {
						MovementObject@ temp_char = remote_players[i];
						Object@ char_obj = ReadObjectFromID(temp_char.GetID());
						ScriptParams@ params = char_obj.GetScriptParams();
						if(params.HasParam("Name")) {
							string name_str = params.GetString("Name");
							if(remote_player_name == name_str) {
								remote_player_id = i;
								break;
							}
						}
					}

					PrintDebug("id: " + remote_player_id + "\tname: " + remote_player_name + "\n");

					if(remote_player_id != -1) {
						MovementObject@ remote_player = remote_players[remote_player_id];

						if(remote_player is null) {
							continue;
						}

						if(remote_player.GetID() != -1) {
							remote_player.Execute("lives = "+remote_player_lives+";");
							remote_player.Execute("cut_throat = "+remote_player_cut_throat+";");
							remote_player.Execute("cut_torso = "+remote_player_cut_torso+";");
							remote_player.Execute("blood_amount = "+remote_player_blood_amount+";");
							remote_player.Execute("recovery_time = "+remote_player_recovery_time+";");
							remote_player.Execute("roll_recovery_time = "+remote_player_roll_recovery_time+";");

							if(remote_player_remove_blood) {
								remote_player.Execute("this_mo.rigged_object().CleanBlood();");
							}

							remote_player.Execute("SetKnockedOut("+remote_player_knocked_out+");");

							remote_player.Execute("blood_damage = "+remote_player_blood_damage+";");
							remote_player.Execute("blood_health = "+remote_player_blood_health+";");
							remote_player.Execute("block_health = "+remote_player_block_health+";");
							remote_player.Execute("temp_health = "+remote_player_temp_health+";");
							remote_player.Execute("permanent_health = "+remote_player_permanent_health+";");

							remote_player.Execute("MPWantsToJump = "+remote_player_jump+";");
							remote_player.Execute("MPWantsToCrouch = "+remote_player_crouch+";");
							remote_player.Execute("MPWantsToAttack = "+remote_player_attack+";");
							remote_player.Execute("MPWantsToGrab = "+remote_player_grab+";");
							remote_player.Execute("MPWantsToItem = "+remote_player_item+";");
							remote_player.Execute("MPWantsToDrop = "+remote_player_drop+";");
							remote_player.Execute("MPWantsToRoll = "+remote_player_roll+";");
							remote_player.Execute("MPWantsToJumpOffWall = "+remote_player_jumpoffwall+";");
							remote_player.Execute("MPActiveBlock = "+remote_player_activeblock+";");

							if(remote_player_dirx == 0.0f) {
								remote_player.Execute("dir_x = 0.0f;");
							} else{
								remote_player.Execute("dir_x = "+ remote_player_dirx +";");
							}
							if(remote_player_dirz == 0.0f) {
								remote_player.Execute("dir_z = 0.0f;");
							} else{
								remote_player.Execute("dir_z = "+ remote_player_dirz +";");
							}
							remote_player.position.x = remote_player_posx;
							remote_player.position.y = remote_player_posy;
							remote_player.position.z = remote_player_posz;

							// Only set the states manually to ragdoll and unragdoll characters when they are in
							// the wrong state. Syncing all states disrupts the fighting.
							int old_state = remote_player.GetIntVar("state");
							if(remote_player_state != old_state) {
								if(remote_player_state == _ragdoll_state) {
									remote_player.Execute("ragdoll_counter++;");

									// It causes massive problems when a character is only ragdolled for some ms, so
									// only sync ragdoll states that last more than 1 or 2 updates.
									if (remote_player.GetIntVar("ragdoll_counter") > 7) {
										PrintDebug("Ragdolling player\n");
									
										remote_player.Execute("Ragdoll("+remote_player_ragdoll_type+");");
									}
								} else if(old_state == _ragdoll_state) {
									PrintDebug("UnRagdolling player\n");
								
									remote_player.Execute("ragdoll_counter = 0;");
									remote_player.Execute("SetState(_movement_state);");
									remote_player.Execute("ApplyIdle(5.0f,true);");
								}
							}
						}
					}
				} else if(type == "UpdateSelf") {
					float player_blood_damage = update["blood_damage"].asFloat();
					float player_blood_health = update["blood_health"].asFloat();
					float player_block_health = update["block_health"].asFloat();
					float player_temp_health = update["temp_health"].asFloat();
					float player_permanent_health = update["permanent_health"].asFloat();
					int player_knocked_out = update["knocked_out"].asInt();
					int player_lives = update["lives"].asInt();
					float player_blood_amount = update["blood_amount"].asFloat();
					float player_recovery_time = update["recovery_time"].asFloat();
					float player_roll_recovery_time = update["roll_recovery_time"].asFloat();
					int player_ragdoll_type = update["ragdoll_type"].asInt();
					bool player_remove_blood = update["remove_blood"].asBool();
					bool player_cut_throat = update["cut_throat"].asBool();
					bool player_cut_torso = update["cut_torso"].asBool();

					//PrintDebug("Self update\n");
					int player_id = GetPlayerCharacterID();
					
					if(player_id == -1) {
						continue;
					}
					
					MovementObject@ char = ReadCharacter(player_id);
					char.Execute("blood_damage = "+player_blood_damage+";");
					char.Execute("blood_health = "+player_blood_health+";");
					char.Execute("block_health = "+player_block_health+";");
					char.Execute("temp_health = "+player_temp_health+";");
					char.Execute("permanent_health = "+player_permanent_health+";");
					char.Execute("knocked_out = "+player_knocked_out+";");
					char.Execute("lives = "+player_lives+";");
					char.Execute("blood_amount = "+player_blood_amount+";");
					char.Execute("recovery_time = "+player_recovery_time+";");
					char.Execute("roll_recovery_time = "+player_roll_recovery_time+";");
					char.Execute("cut_throat = "+player_cut_throat+";");
					char.Execute("cut_torso = "+player_cut_torso+";");

					if(player_remove_blood) {
						char.Execute("this_mo.rigged_object().CleanBlood();");
					}
				} else if(type == "Message") {
					string remote_username = update["name"].asString();
					string text = update["text"].asString();
					string notif = update["notif"].asString();

					PrintDebug("Adding chat message: " + "addChat(\""+remote_username+"\",\""+text+"\","+notif+")" + "\n");
					gui.Execute(chat_id,"addChat(\""+remote_username+"\",\""+text+"\","+notif+")");
				} else if(type == "LoadPosition") {
					PlaySound("Data/Sounds/ambient/amb_canyon_hawk_1.wav");
					PrintDebug("Received loadpostion message." + "\n");

					//Reset velocity to avoid being crunched to death.
					MovementObject@ char = ReadCharacter(0);
					char.velocity = vec3(0);

					char.position.x = update["posx"].asFloat();
					char.position.y = update["posy"].asFloat();
					char.position.z = update["posz"].asFloat();

					// Reset animations to avoid the strange hands.
					char.Execute("ResetSecondaryAnimation();");
				}
			}

			callback = gui.GetCallback(client_connect_id);
		}
	}
}

void HandleChat() {
	if(!connected_to_server) {
		return;
	}

	string callback = gui.GetCallback(chat_id);

	while(callback != "") {
		if(callback == '!unfocus') {
			has_chat_gui = false;
			break;
		}

		JSON chatData;
		JSONValue chatDataRoot( JSONobjectValue );
		chatDataRoot["type"] = "Message";
		chatDataRoot["name"] = "username";
		chatDataRoot["uid"] = "client_uid";
		chatDataRoot["uid"] = callback;
		chatData.getRoot() = chatDataRoot;

		gui.Execute(client_connect_id,"sendUpdate(" + chatData.writeString(true) + ")");

		has_chat_gui = false;
		callback = gui.GetCallback(chat_id);
	}
}

void DrawUsernames() {
	if(!connected_to_server) {
		return;
	}

	int num = GetNumCharacters();
	for(int i=0; i<num; ++i) {
		MovementObject@ char = ReadCharacter(i);
		Object @obj = ReadObjectFromID(char.GetID());
		ScriptParams@ params = obj.GetScriptParams();
		if(!params.HasParam("Name")) {
			return;
		}
		string new_string = params.GetString("Name");

		int num_canvases = int(dialogue_text_canvases.size());
		int assigned_canvas = -1;
		for(int j=0; j<num_canvases; ++j) {
			if(dialogue_text_canvases[j].obj_id == obj.GetID()) {
				assigned_canvas = j;
			}
		}
		if(assigned_canvas == -1) {
			dialogue_text_canvases.resize(num_canvases+1);
			dialogue_text_canvases[num_canvases].obj_id = obj.GetID();
			dialogue_text_canvases[num_canvases].text = "";
			dialogue_text_canvases[num_canvases].canvas_id = level.CreateTextElement();
			TextCanvasTexture @text = level.GetTextElement(dialogue_text_canvases[num_canvases].canvas_id);
			text.Create(256, 256);
			assigned_canvas = num_canvases;
		}
		DialogueTextCanvas @assigned = dialogue_text_canvases[assigned_canvas];
		TextCanvasTexture @text = level.GetTextElement(assigned.canvas_id);
		if(assigned.text != new_string) {
			text.ClearTextCanvas();
			string font_str = "Data/Fonts/arial.ttf";
			TextStyle small_style;
			int font_size = 24;
			small_style.font_face_id = GetFontFaceID(font_str, font_size);
			text.SetPenColor(255,255,255,255);
			text.SetPenRotation(0.0f);
			TextMetrics metrics;
			text.GetTextMetrics(new_string, small_style, metrics);
			text.SetPenPosition(vec2(128-metrics.advance_x/64.0f*0.5f, 210));
			text.AddText(new_string, small_style);
			text.UploadTextCanvasToTexture();
			assigned.text = new_string;
		}
		vec3 name_text_pos = vec3(char.position.x, char.position.y + 1.5f, char.position.z);
		text.DebugDrawBillboard(name_text_pos, obj.GetScale().x, _delete_on_update);
	}
}

void SendUpdate() {
	if(connected_to_server) {
		delay -= time_step;
		if(delay <= 0.0f) {
			MovementObject@ char = ReadCharacter(0);

			JSON updateData;
			JSONValue updateDataRoot( JSONobjectValue );
			updateDataRoot["type"] = "Update";
			updateDataRoot["uid"] = "client_uid";
			updateDataRoot["posx"] = char.position.x;
			updateDataRoot["posy"] = char.position.y;
			updateDataRoot["posz"] = char.position.z;
			updateDataRoot["dirx"] = char.GetFloatVar("dir_x");
			updateDataRoot["dirz"] = char.GetFloatVar("dir_z");
			updateDataRoot["crouch"] = char.GetBoolVar("MPWantsToCrouch");
			updateDataRoot["jump"] = char.GetBoolVar("MPWantsToJump");
			updateDataRoot["attack"] = char.GetBoolVar("MPWantsToAttack");
			updateDataRoot["grab"] = char.GetBoolVar("MPWantsToGrab");
			updateDataRoot["item"] = char.GetBoolVar("MPWantsToItem");
			updateDataRoot["drop"] = char.GetBoolVar("MPWantsToDrop");
			updateDataRoot["roll"] = char.GetBoolVar("MPWantsToRoll");
			updateDataRoot["offwall"] = char.GetBoolVar("MPWantsToJumpOffWall");
			updateDataRoot["activeblock"] = char.GetBoolVar("MPActiveBlock");
			updateDataRoot["blood_damage"] = char.GetFloatVar("blood_damage");
			updateDataRoot["blood_health"] = char.GetFloatVar("blood_health");
			updateDataRoot["block_health"] = char.GetFloatVar("block_health");
			updateDataRoot["temp_health"] = char.GetFloatVar("temp_health");
			updateDataRoot["permanent_health"] = char.GetFloatVar("permanent_health");
			updateDataRoot["knocked_out"] = char.GetIntVar("knocked_out");
			updateDataRoot["lives"] = char.GetIntVar("lives");
			updateDataRoot["blood_amount"] = char.GetFloatVar("blood_amount");
			updateDataRoot["recovery_time"] = char.GetFloatVar("recovery_time");
			updateDataRoot["roll_recovery_time"] = char.GetFloatVar("roll_recovery_time");
			updateDataRoot["ragdoll_type"] = char.GetIntVar("ragdoll_type");
			updateDataRoot["blood_delay"] = char.GetIntVar("blood_delay");
			updateDataRoot["cut_throat"] = char.GetBoolVar("cut_throat");
			updateDataRoot["cut_torso"] = char.GetBoolVar("MPWacut_torsotsToGrab");
			updateDataRoot["state"] = char.GetIntVar("state");
			updateData.getRoot() = updateDataRoot;

			char.Execute("MPWantsToRoll = false;");
			char.Execute("MPWantsToJumpOffWall = false;");
			char.Execute("MPActiveBlock = false;");

			gui.Execute(client_connect_id,"sendUpdate(" + updateData.writeString(true) + ")");
			delay += frequency;
		}
	}
}

void Disconnect() {
	connected_to_server = false;
	MovementObject@ char = ReadCharacter(0);
	char.Execute("MPIsConnected = false;");

	// Notify player.
	gui.Execute(chat_id,"addChat('System', 'Connection to server lost.', true)");

	// Remove other players.
	int num = GetNumCharacters();
	for(int i = 1; i<num; i++) {
		MovementObject@ other_char = ReadCharacter(i);
		PrintDebug("Delete character" + other_char.GetID() + "\n");
		DeleteObjectID(other_char.GetID());
	}
	remote_players.resize(0);

	//Every known character needs to be removed or else the situationawareness script will check the nonexisting movementobjects
	char.Execute("situation.clear();");
}

bool HasOGMPFocus() {
	if(showing_playerlist || has_client_connect_gui) {
		return true;
	}

	if((has_gui || connected_to_server) && (!connected_to_server || has_chat_gui)) {
		return true;
	}

	return false;
}

void PrintDebug(string str) {
	if(debug) {
		Print(str);
	}
}
