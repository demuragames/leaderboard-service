SRC=main.vala
leaderboard: $(SRC)
	valac -g --save-temps -X -O0 -o leaderboard --pkg libsoup-2.4 --define=LIBPQ_9_3 -X -I/usr/include/pgsql -X -lpq --pkg libpq --thread $(SRC)
clean:
	rm -f leaderboard

