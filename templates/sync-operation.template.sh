#! /bin/bash

# configurazione (generata da wp-bootstrap)
RC_USER={{RC_USER}}

RC_APP_NAME={{RC_APP_NAME}}
W_URL_REMOTE={{W_URL_REMOTE}}

RC_SERVERNAME={{RC_SERVERNAME}}

W_URL_LOCAL={{W_URL_LOCAL}}


date=$(date '+%Y-%m-%d-%H%M');
NOME_DB_REMOTE=export-remote-$date.sql
NOME_DB_LOCAL=export-local-$date.sql

case "$1" in
db:pull)
  /bin/bash -l -c "ssh $RC_USER@$RC_SERVERNAME 'cd webapps/$RC_APP_NAME; wp db export $NOME_DB_REMOTE'" &&
  /bin/bash -l -c "scp $RC_USER@$RC_SERVERNAME:/home/$RC_USER/webapps/$RC_APP_NAME/$NOME_DB_REMOTE tmp/$NOME_DB_REMOTE" &&
  /bin/bash -l -c "ssh $RC_USER@$RC_SERVERNAME 'cd webapps/$RC_APP_NAME; rm $NOME_DB_REMOTE'"&&
  /bin/bash -l -c "cp tmp/$NOME_DB_REMOTE export.sql" &&
  /bin/bash -l -c "wp db import export.sql" &&
  /bin/bash -l -c "wp search-replace '$W_URL_REMOTE' '$W_URL_LOCAL'"&&
  /bin/bash -l -c "wp rewrite flush"&&
  /bin/bash -l -c "rm export.sql"
  ;;

git:status)
  /bin/bash -l -c "ssh $RC_USER@$RC_SERVERNAME 'cd webapps/$RC_APP_NAME; git status'";
  ;;

console)
  /bin/bash -l -c "ssh $RC_USER@$RC_SERVERNAME 'cd webapps/$RC_APP_NAME; wp shell'"
  ;;

ssh)
  ssh $RC_USER@$RC_SERVERNAME
  ;;

db:push)
  SEARCHREPLACE=$"wp search-replace '$W_URL_LOCAL'  '$W_URL_REMOTE'";
  /bin/bash -l -c "wp db export tmp/$NOME_DB_LOCAL" &&
  /bin/bash -l -c "scp tmp/$NOME_DB_LOCAL $RC_USER@$RC_SERVERNAME:/home/$RC_USER/webapps/$RC_APP_NAME" &&
  /bin/bash -l -c "ssh $RC_USER@$RC_SERVERNAME 'cd webapps/$RC_APP_NAME;
                      wp db import $NOME_DB_LOCAL;'"  &&
  /bin/bash -l -c "ssh $RC_USER@$RC_SERVERNAME 'cd webapps/$RC_APP_NAME;
                        $SEARCHREPLACE;'"&&
  /bin/bash -l -c "ssh $RC_USER@$RC_SERVERNAME 'cd webapps/$RC_APP_NAME;
                      rm $NOME_DB_LOCAL;'"&&
  /bin/bash -l -c "ssh $RC_USER@$RC_SERVERNAME 'cd webapps/$RC_APP_NAME;
                      wp rewrite flush;'"
  ;;

assets:pull)
  /bin/bash -l -c "rsync -azv --ignore-existing rc-$RC_USER:webapps/$RC_APP_NAME/wp-content/uploads wp-content"
  ;;
assets:push)
  /bin/bash -l -c "rsync -azv --ignore-existing wp-content/uploads rc-$RC_USER:webapps/$RC_APP_NAME/wp-content"
  ;;

themes:pull)
  /bin/bash -l -c "rsync -azv --ignore-existing rc-$RC_USER:webapps/$RC_APP_NAME/wp-content/themes wp-content"
  ;;
themes:push)
  /bin/bash -l -c "rsync -azv --ignore-existing wp-content/themes rc-$RC_USER:webapps/$RC_APP_NAME/wp-content"
  ;;

plugins:pull)
  /bin/bash -l -c "rsync -azv --ignore-existing rc-$RC_USER:webapps/$RC_APP_NAME/wp-content/plugins wp-content"
  ;;
plugins:push)
  /bin/bash -l -c "rsync -azv --ignore-existing wp-content/plugins rc-$RC_USER:webapps/$RC_APP_NAME/wp-content"
  ;;

  *)
  echo >&2 "Usage: $0 <db:pull|db:push|assets:pull|assets:push|themes:pull|themes:push|plugins:pull|plugins:push|git:status|console|ssh>"
  exit 1
  ;;
esac
