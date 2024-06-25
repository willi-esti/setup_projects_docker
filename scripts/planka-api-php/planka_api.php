<?php

if (posix_getuid() != 0) {
    echo "Script is running as root. Exiting...";
    exit;
}

use Planka\Bridge\PlankaClient;
use Planka\Bridge\TransportClients\Client;
use Planka\Bridge\Config;
//use Planka\Bridge\Actions\Card\CardCreateAction;

require __DIR__ . '/vendor/autoload.php';

include_once('/opt/vault/passwords.php');

$config = new Config(
    user: PLANKA_USER,
    password: PLANKA_PWD,
    baseUri: PLANKA_HOST,
    port: 443
);

$planka = new PlankaClient($config);

$planka->authenticate();

$today = date("Y-m-d H:i:s");
$projectId = '1268932553713124751';
$initialListId = '1268933917876946323';
$destinationListId = '1268939791127283093';
$errorListId = '1268940194023736726';
$card = $planka->card->create($initialListId, "$today", 1);
$output = shell_exec("/bin/bash /opt/scripts/backup_httpd.sh daily; echo $?");
echo $output;
$planka->cardMembership->add($card->id, '1259231137159447555');

$card->description = $output;
$planka->card->update($card);

$card->listId = $destinationListId;
$planka->card->moveCard($card);

#CardDto $card = $planka->card->get($initialListId);
#$planka->projectViewAction($projectId);
//$planka->card->moveCard();
//$planka->cardMembership->remove($initialListId, '1259231137159447555');
$planka->logout();

