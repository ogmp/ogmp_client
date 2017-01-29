uint socket = SOCKET_ID_INVALID;
uint connect_try_countdown = 5;
string level_name = "";
int player_id = -1;

int ragdoll_counter = 0;
float dir_x = 0.0f;
float dir_z = 0.0f;

bool MPWantsToCrouch = false;
bool MPWantsToJump = false;
bool MPWantsToAttack = false;
bool MPWantsToGrab = false;
bool MPWantsToItem = false;
bool MPWantsToDrop = false;
bool MPWantsToRoll = false;
bool MPWantsToJumpOffWall = false;
bool MPActiveBlock = false;
bool MPIsConnected = false;

bool connected_to_server = false;
bool post_init_run = false;
bool trying_to_connect = false;

float update_timer = 0.0f;
float interval = 1.0f;

void Init(string p_level_name) {
    level_name = p_level_name;
    player_id = GetPlayerCharacterID();
}

void IncomingTCPData(uint socket, array<uint8>@ data) {
    Log(info, "Data in" );
    //string s(data, data + data.length());
    array<string> complete;
    for( uint i = 0; i < data.length(); i++ ) {
        string s('0');
        s[0] = data[i];
        complete.insertLast(s);
    }
    Log(info, "Data: " + join(complete, ""));
}

void ReceiveMessage(string msg) {
}

void DrawGUI() {
}

void Update(int paused) {
    if(!post_init_run){
        player_id = GetPlayerCharacterID();
        post_init_run = true;
    }

    if(connected_to_server){
        UpdatePlayerVariables();
        SendPlayerUpdate();
        ReceiveServerUpdate();
    }else{
        PreConnectedKeyChecks();
        ConnectToServer();
    }
}

void SetWindowDimensions(int w, int h)
{
}

void PreConnectedKeyChecks(){
    if(GetInputPressed(ReadCharacter(player_id).controller_id, "f12") && !trying_to_connect){
        Log(info, "Trying to connect to server");
        trying_to_connect = true;
    }
}

void ConnectToServer(){
    if(trying_to_connect){
        if( socket == SOCKET_ID_INVALID ) {
            if( connect_try_countdown == 0 ) {
                if( level_name != "") {
                    Log( info, "Trying to connect" );
                    socket = CreateSocketTCP("127.0.0.1", 2000);
                    if( socket != SOCKET_ID_INVALID ) {
                        Log( info, "Connected " + socket );
                        connected_to_server = true;
                    } else {
                        Log( warning, "Unable to connect, will try again soon" );
                        connect_try_countdown = 60*5;
                    }
                }
            } else {
                connect_try_countdown--;
            }
        }
    }
}

void SendPlayerUpdate(){
    array<string> messages = {"This is the first message", "and another one", "bloop", "soooo", "hmm yeah"};
    if(update_timer > interval){
        Log(info, "Send update");
        update_timer = 0;
        SendData(messages[rand()%messages.size()]);
    }
    update_timer += time_step;
}

void ReceiveServerUpdate(){}

void UpdatePlayerVariables(){
    MPWantsToCrouch = GetInputDown(ReadCharacter(player_id).controller_id, "crouch");
    MPWantsToJump = GetInputDown(ReadCharacter(player_id).controller_id, "jump");
    MPWantsToAttack = GetInputDown(ReadCharacter(player_id).controller_id, "attack");
    MPWantsToGrab = GetInputDown(ReadCharacter(player_id).controller_id, "grab");
    MPWantsToItem = GetInputDown(ReadCharacter(player_id).controller_id, "item");
    MPWantsToDrop = GetInputDown(ReadCharacter(player_id).controller_id, "drop");
    if(GetInputPressed(ReadCharacter(player_id).controller_id, "crouch")) {
      MPWantsToRoll = true;
    }
    if(GetInputPressed(ReadCharacter(player_id).controller_id, "jump")) {
      MPWantsToJumpOffWall = true;
    }
    if(GetInputPressed(ReadCharacter(player_id).controller_id, "grab")) {
      MPActiveBlock = true;
    }
    //dir_x = ReadCharacter(player_id).GetFloatVar("GetTargetVelocity().x");
    //dir_z = ReadCharacter(player_id).GetFloatVar("GetTargetVelocity().y");
    //Log(info, dir_x + " dir_x");
    //Log(info, dir_z + " dir_z");
}

void SendData(string message){
    if( IsValidSocketTCP(socket) )
    {
        Log(info, "Sending data" );
        array<uint8> data;
        for(uint i = 0; i < message.length(); i++){
            data.insertLast(message.substr(i, 1)[0]);
        }
        data.insertLast('\n'[0]);
        Log(info, "Data size " + data.size() );
        SocketTCPSend(socket,data);
    }
    else
    {
        socket = SOCKET_ID_INVALID;
    }
}

int GetPlayerCharacterID() {
    int num = GetNumCharacters();
    for(int i=0; i<num; ++i){
        MovementObject@ char = ReadCharacter(i);
        if(char.controlled){
            return i;
        }
    }
    return -1;
}
