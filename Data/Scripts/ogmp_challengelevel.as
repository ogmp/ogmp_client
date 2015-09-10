bool IsMultiplayer() {
	int player_id = GetPlayerCharacterID();

	if(player_id == -1) {
		return false;
	}

	MovementObject@ char = ReadCharacter(player_id);

	return char.GetBoolVar("MPIsConnected");
}
