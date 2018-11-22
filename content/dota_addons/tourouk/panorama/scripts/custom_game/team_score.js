function UpdateScore(table_name, key, data) {
	$.Msg(data)

	if (data.radiant)
		$("#TeamScoreLabelRadiant").text = data.radiant;
	if (data.dire)
		$("#TeamScoreLabelDire").text = data.dire;
}

(function () {
	CustomNetTables.SubscribeNetTableListener("game_options", UpdateScore)
})();
