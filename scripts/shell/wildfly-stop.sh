#!/usr/bin/env bash
# Gracefully stop WildFly using the management CLI and print PID(s)
WILDFLY_HOME="$(dirname "$0")/../../wildfly-37.0.0.Final"
PIDS=$(pgrep -f "wildfly.*standalone")
if [ -z "$PIDS" ]; then
	echo "No WildFly process found."
else
	echo "Stopping WildFly process(es) with PID(s): $PIDS"
	"$WILDFLY_HOME/bin/jboss-cli.sh" --connect command=:shutdown
	# Give it a moment to shut down gracefully
	sleep 2
	# If still running, force kill
	for PID in $PIDS; do
		if kill -0 $PID 2>/dev/null; then
			echo "Force killing WildFly process $PID"
			kill -9 $PID
		fi
	done
fi
