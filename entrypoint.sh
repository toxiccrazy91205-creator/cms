#!/bin/bash
set -e

echo "Starting PostgreSQL..."
service postgresql start

# Wait for Postgres to be ready
while ! su - postgres -c "psql -c '\q'" 2>/dev/null; do
  echo "Waiting for PostgreSQL..."
  sleep 1
done

# Check if cmsdb exists, if not, initialize it
if ! su - postgres -c "psql -lqt | cut -d \| -f 1 | grep -qw cmsdb"; then
    echo "Initializing CMS Database..."
    su - postgres -c "createdb cmsdb"
    su - postgres -c "createuser -s cmsuser"
    su - postgres -c "psql -c \"ALTER USER cmsuser WITH PASSWORD 'cms';\""
    
    # Initialize the CMS DB Schema
    echo "Running cmsInitDB..."
    su - cmsuser -c "/home/cmsuser/cms/bin/cmsInitDB"
    
    # Add default admin
    echo "Adding default admin (admin / admin)"
    su - cmsuser -c "/home/cmsuser/cms/bin/cmsAddAdmin admin -p admin"
fi

echo "Starting CMS Web Services..."
# We run the servers in the background and wait.
# NOTE: EvaluationService and ResourceService are disabled because Render blocks isolate (cgroups).
su - cmsuser -c "/home/cmsuser/cms/bin/cmsLogService" &
su - cmsuser -c "/home/cmsuser/cms/bin/cmsAdminWebServer" &
# su - cmsuser -c "/home/cmsuser/cms/bin/cmsContestWebServer" &

echo "CMS Web Servers are running!"
echo "Admin UI is exposed. Note: Render only forwards ONE port publicly to the web service."

# Keep container alive by waiting for background processes
wait -n
