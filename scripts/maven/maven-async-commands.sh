#!/bin/bash

# Maven WildFly Async Command Wrapper
# Provides convenient commands for the unified async WildFly system

echo "🚀 MAVEN WILDFLY ASYNC COMMANDS"
echo "==============================="
echo ""

COMMAND=${1:-"help"}
shift

case "$COMMAND" in
    "start")
        echo "🚀 Starting WildFly Async System..."
        mvn validate -Pwildfly-async-start "$@"
        ;;
    "stop")
        echo "🛑 Stopping WildFly Async System..."
        mvn validate -Pwildfly-async-stop "$@"
        ;;
    "deploy")
        echo "🚀 Deploying via WildFly Async System..."
        mvn validate -Pwildfly-async-deploy "$@"
        ;;
    "status")
        echo "📊 Checking WildFly Async System Status..."
        mvn validate -Pwildfly-async-status "$@"
        ;;
    "dev-deploy")
        echo "🚀 Deploying to Development..."
        mvn validate -Pwildfly-async-deploy -Pdevelopment "$@"
        ;;
    "staging-deploy")
        echo "🚀 Deploying to Staging..."
        mvn validate -Pwildfly-async-deploy -Pstaging "$@"
        ;;
    "prod-deploy")
        echo "🚀 Deploying to Production..."
        mvn validate -Pwildfly-async-deploy -Pproduction "$@"
        ;;
    "health-check")
        echo "🔍 Running Health Check..."
        mvn validate -Pwildfly-async-start -Djob.type=health_check "$@"
        ;;
    "cache-warmup")
        echo "🔥 Warming up Cache..."
        mvn validate -Pwildfly-async-start -Djob.type=cache_warmup "$@"
        ;;
    "help")
        echo "📋 Available Commands:"
        echo "   start            # Start async WildFly system"
        echo "   stop             # Stop async WildFly system"
        echo "   deploy           # Deploy via async system"
        echo "   status           # Check system status"
        echo "   dev-deploy       # Deploy to development"
        echo "   staging-deploy   # Deploy to staging"
        echo "   prod-deploy      # Deploy to production"
        echo "   health-check     # Run health check"
        echo "   cache-warmup     # Warm authentication cache"
        echo ""
        echo "📋 Examples:"
        echo "   ./scripts/maven/maven-async-commands.sh start"
        echo "   ./scripts/maven/maven-async-commands.sh deploy -Djob.type=build_only"
        echo "   ./scripts/maven/maven-async-commands.sh dev-deploy -Dskip.tests=true"
        echo "   ./scripts/maven/maven-async-commands.sh status"
        echo ""
        echo "📋 Direct Maven Commands:"
        echo "   mvn validate -Pwildfly-async-start"
        echo "   mvn validate -Pwildfly-async-deploy -Pdevelopment"
        echo "   mvn validate -Pwildfly-async-status"
        echo ""
        ;;
    *)
        echo "❌ Unknown command: $COMMAND"
        echo "   Use: ./scripts/maven/maven-async-commands.sh help"
        exit 1
        ;;
esac