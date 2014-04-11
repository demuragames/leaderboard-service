using GLib;

class Player
{
    public string identifier;
    public int score;
    public Player(string i, int s) {identifier = i; score = s;}
}

Postgres.Database db;

List<Player> get_top_players ()
{
    List<Player> list = new List<Player>();

    var result = db.exec ("SELECT * FROM leaderboard ORDER BY score DESC LIMIT 10");
    if (result.get_status () != Postgres.ExecStatus.TUPLES_OK)
    {
        stderr.printf ("SELECT * FROM leaderboard failed: %s", db.get_error_message ());
        return list;
    }

    for (int i = 0; i < result.get_n_tuples(); i++)
    {
        string identifier = result.get_value (i, 0);//.strip();
        int score = int.parse(result.get_value (i, 1));
    	list.append(new Player(identifier, score));
    }

    return list;
}

void top_handler (Soup.Server server, Soup.Message msg, string path, HashTable? query, Soup.ClientContext client)
{
    List<Player> top_players = get_top_players ();
    string response_text = "";
    foreach (Player player in top_players)
    {
        response_text += @"$(player.identifier) $(player.score)\n";
    }
    msg.set_response ("text/plain", Soup.MemoryUse.COPY, response_text.data);
}

void report_handler (Soup.Server server, Soup.Message msg, string path, HashTable? query, Soup.ClientContext client)
{
    HashTable<string, string> table = (HashTable<string, string>)query;

    if (table.contains("id") && table.contains("score"))
    {
        string identifier = table.get("id");
        int score = int.parse(table.get("score"));

        var result = db.exec (@"SELECT count(*) FROM leaderboard WHERE identifier='$(identifier)'");
        if (result.get_status () != Postgres.ExecStatus.TUPLES_OK)
        {
            stderr.printf ("SELECT * FROM leaderboard failed: %s", db.get_error_message ());
            return;
        }

	if (int.parse(result.get_value (0, 0)) > 0)
        {
            db.exec (@"UPDATE leaderboard SET score=$(score) WHERE identifier='$(identifier)' AND score < $(score)");
        }
        else
        {
            db.exec (@"INSERT INTO leaderboard VALUES ('$(identifier)', $(score))");
        }
    }
}

int main (string[] args)
{
    db = Postgres.connect_db ("host=postgres8.1gb.ua port=5432 dbname=xgbua_flappy user=xgbua_flappy password=18f2f978e0");
    if (db.get_status () != Postgres.ConnectionStatus.OK)
    {
        stderr.printf ("Connection to database failed: %s", db.get_error_message ());
        return 1;
    }

    Soup.Server server = new Soup.Server (Soup.SERVER_PORT, 8080);
    server.add_handler ("/top", top_handler);
    server.add_handler ("/report", report_handler);
    server.run ();

    return 0;
}

