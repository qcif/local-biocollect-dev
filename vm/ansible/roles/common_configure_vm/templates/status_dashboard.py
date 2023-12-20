import json
import logging
import pathlib
import typing
import asyncio
from dataclasses import dataclass
import sys
from datetime import timezone, datetime

import psutil
from pystemd.systemd1 import Unit, Manager
from pystemd.dbusexc import DBusInterruptedError
from quart import Quart, abort, make_response, request

logging.basicConfig(
    format="%(asctime)s [%(levelname)-8s] %(message)s",
    datefmt="%a %d %b %H:%M:%S",
    level=logging.DEBUG,
)

logger = logging.getLogger(__name__)

TIME_BETWEEN_EVENTS_SEC = 5


def get_local_tcp_ports():
    """Get the local TCP ports and associated process id.

    :return: Port and process id details.
    """
    count = 0
    for conn in psutil.net_connections(kind="tcp"):
        count += 1
        yield {
            "pid": str(conn.pid),
            "port": str(conn.laddr.port),
        }
    logger.info("Found %s local tcp connections.", count)


def get_service(name) -> dict[str, typing.Any]:
    """Get details for the systemd service with the given name.

    :param name: The systemd service name.
    :return: The details about the service.
    """
    name_enc = name.encode("utf-8")
    with Unit(name_enc) as u:
        processes = [
            {
                "pid": str(pid),
                "cmdline": cmd_line.decode("utf-8").strip().split(" ")[-1],
            }
            for unit_slice, pid, cmd_line in u.Service.GetProcesses()
        ]

    logger.debug("Found systemd unit %s.", name)

    return {
        "name": name.replace(".service", "").strip(),
        "unit_name": name.strip(),
        "active_state": u.Unit.ActiveState.decode("utf-8"),
        "sub_state": u.Unit.SubState.decode("utf-8"),
        "processes": processes,
    }


def get_services_ports(
    service_names: list[str] | None = None,
) -> list[dict[str, typing.Any]]:
    """Get the linked services and ports.

    :param service_names: The service names to look at.
    :return: The service, process, and port details.
    """

    # find all services that start with 'app_' if service names are not provided
    if not service_names:
        service_names = []
        logger.info("Finding systemd unit files.")
        with Manager() as manager:
            try:
                for unit, state in manager.Manager.ListUnitFilesByPatterns(
                    [], ["app_*"]
                ):
                    unit_path = pathlib.Path(unit.decode("utf-8"))
                    with Unit(unit_path.name) as u:
                        logger.debug("Found unit %s.", str(u))
                        for name in u.Unit.Names:
                            service_names.append(name.decode("utf-8"))
            except DBusInterruptedError:
                logger.exception("Could not list systemd unit files.")

    logger.info("Linking ports to services %s.", sorted(service_names))

    # create a mapping of pids to ports
    pids_ports = {}
    for item in get_local_tcp_ports():
        pid = item.get("pid")
        port = item.get("port")
        if pid not in pids_ports:
            pids_ports[pid] = set()
        if port not in pids_ports[pid]:
            pids_ports[pid].add(port)

    # gather the ports for each services' pids
    services = []
    for service_name in service_names:
        service = get_service(service_name)
        for service_port in service.get("processes"):
            pid = service_port.get("pid")
            if pid in pids_ports:
                if "ports" not in service_port:
                    service_port["ports"] = []
                ports = pids_ports[pid]
                for port in ports:
                    if len(port) == 4:
                        service_port["ports"].append(port)
        services.append(service)

    logger.info("Build info for services %s.", services)

    return services


@dataclass
class ServerSentEvent:
    data: str
    event: str | None = None
    id: int | None = None
    retry: int | None = None

    def encode(self) -> bytes:
        message = f"data: {self.data}"
        if self.event is not None:
            message = f"{message}\nevent: {self.event}"
        if self.id is not None:
            message = f"{message}\nid: {self.id}"
        if self.retry is not None:
            message = f"{message}\nretry: {self.retry}"
        message = f"{message}\n\n"
        return message.encode("utf-8")


def build_event(services_data: list[dict]) -> ServerSentEvent:
    now = datetime.now(timezone.utc)
    return ServerSentEvent(
        data=json.dumps(
            {"services": services_data, "time": now.isoformat(timespec="seconds")}
        ),
        event="status_update",
        id=int(now.timestamp()),
        retry=TIME_BETWEEN_EVENTS_SEC * 1000,  # in milliseconds
    )


app = Quart(__name__)


@app.get("/")
async def sse():
    if "text/event-stream" not in request.accept_mimetypes:
        abort(400)

    async def send_events():
        while True:
            raw = get_services_ports()
            event = build_event(raw)
            logger.info("Sending event %s.", event)
            yield event.encode()
            await asyncio.sleep(TIME_BETWEEN_EVENTS_SEC)

    response = await make_response(
        send_events(),
        {
            "Content-Type": "text/event-stream",
            "Cache-Control": "no-cache",
            "Transfer-Encoding": "chunked",
        },
    )
    response.timeout = None
    return response


def main(args=None) -> int:
    if not args:
        args = sys.argv[1:]

    # run in develop mode
    app.run(port=int("{{ specified_ports.dashboard_http_port }}"))

    return 0


if __name__ == "__main__":
    sys.exit(main())
