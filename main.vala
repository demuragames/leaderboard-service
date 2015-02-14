using GLib;

class Player
{
    public string identifier;
    public int score;
    public Player (string i, int s) {identifier = i; score = s;}
}

Postgres.Database db;

List<Player> get_top_players ()
{
    List<Player> list = new List<Player> ();

    var result = db.exec ("SELECT * FROM leaderboard ORDER BY score DESC LIMIT 10");
    if (result.get_status () != Postgres.ExecStatus.TUPLES_OK)
    {
        stderr.printf ("SELECT * FROM leaderboard failed: %s", db.get_error_message ());
        return list;
    }

    for (int i = 0; i < result.get_n_tuples(); i++)
    {
        string identifier = result.get_value (i, 0);//.strip();
        int score = int.parse (result.get_value (i, 1));
        list.append (new Player (identifier, score));
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

    if (table.contains ("id") && table.contains ("score"))
    {
        string identifier = table.get ("id");
        int score = int.parse (table.get ("score"));

        var result = db.exec (@"SELECT count(*) FROM leaderboard WHERE identifier='$(identifier)'");
        if (result.get_status () != Postgres.ExecStatus.TUPLES_OK)
        {
            stderr.printf ("SELECT * FROM leaderboard failed: %s", db.get_error_message ());
            return;
        }

	if (int.parse (result.get_value (0, 0)) > 0)
        {
            db.exec (@"UPDATE leaderboard SET score=$(score) WHERE identifier='$(identifier)' AND score < $(score)");
        }
        else
        {
            db.exec (@"INSERT INTO leaderboard VALUES ('$(identifier)', $(score))");
        }
    }
}

extern void daemonize ();

int port = 5432;
string? host = null;
string? dbname = null;
string? user = null;
string? password = null;

const OptionEntry[] options =
{
    { "host",     'w', 0, OptionArg.STRING, ref host,     N_("PostgreSQL server host name"),   N_("HOST")     },
    { "port",     'd', 0, OptionArg.INT,    ref port,     N_("PostgreSQL server port number"), N_("PORT")     },
    { "dbname",   'v', 0, OptionArg.STRING, ref dbname,   N_("PostgreSQL database name"),      N_("DATABASE") },
    { "user",     'f', 0, OptionArg.STRING, ref user,     N_("PostgreSQL user name"),          N_("USER")     },
    { "password", 'p', 0, OptionArg.STRING, ref password, N_("PostgreSQL password"),           N_("PASSWORD") },
    { null }
};

int main (string[] args)
{
    host = "localhost";

    try 
    {
        var opt_context = new OptionContext ("- Starts leaderboard server as daemon");
        opt_context.set_help_enabled (true);
        opt_context.add_main_entries (options, null);
        opt_context.parse (ref args);

        if (dbname == null)
        {
            throw new GLib.OptionError.FAILED ("database name is not specified");
        }
        if (user == null)
        {
            throw new GLib.OptionError.FAILED ("user name is not specified");
        }
        if (password == null)
        {
            throw new GLib.OptionError.FAILED ("password is not specified");
        }
    }
    catch (OptionError e)
    {
        stdout.printf ("error: %s\n", e.message);
        stdout.printf ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
        return 0;
    }
    finally
    {
    }

    daemonize();

    db = Postgres.connect_db (@"host=$host port=$port dbname=$dbname user=$user password=$password");
    if (db.get_status () != Postgres.ConnectionStatus.OK)
    {
        stderr.printf ("Connection to database failed: %s", db.get_error_message ());
        return 1;
    }

    Soup.Server server = new Soup.Server (Soup.SERVER_PORT, 8088);
    server.add_handler ("/top", top_handler);
    server.add_handler ("/report", report_handler);

    try
    {
        server.listen_all (8080, 0);

        GLib.MainLoop loop = new GLib.MainLoop ();
        loop.run ();
    }
    finally
    {
    }

    return 0;
}







