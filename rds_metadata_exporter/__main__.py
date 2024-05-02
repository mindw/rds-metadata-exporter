from prometheus_client import start_wsgi_server
from prometheus_client.core import Histogram, CounterMetricFamily, InfoMetricFamily, REGISTRY
from prometheus_client.registry import Collector
import time
import botocore.session
import argparse

h = Histogram('collect_duration', 'Description of histogram', unit="seconds")


class RdsCollector(Collector):
    def __init__(self, rds_instance: str, region: str):
        self.rds_instance = rds_instance
        self.session = botocore.session.get_session()
        self.client = self.session.create_client('rds', region_name=region)

    @h.time()
    def collect(self):
        response = self.client.describe_db_instances(
            DBInstanceIdentifier=self.rds_instance
        )
        instance = response["DBInstances"][0]
        labels = {
            "arn": instance["DBInstanceArn"],
            "dbi_resource_id": instance["DbiResourceId"],
            "dbidentifier": instance["DBInstanceIdentifier"],
            "engine": instance["Engine"],
            "engine_version": instance["EngineVersion"],
            "iam_database_authentication_enabled": str(instance["IAMDatabaseAuthenticationEnabled"]),
            "instance_class": instance["DBInstanceClass"],
            "performance_insights_enabled": str(instance["PerformanceInsightsEnabled"]),
            "storage_type": instance["StorageType"],
            "ca_certificate_identifier": instance["CACertificateIdentifier"],
        }

        info = InfoMetricFamily(
            "rds_instance",
            "RDS instance information",
            labels=list(labels.keys())
        )
        info.add_metric(labels=list(labels.keys()), value=labels)
        yield info
        c = CounterMetricFamily(
            "rds_max_allocated_storage",
            "Upper limit in gibibytes to which Amazon RDS can automatically scale the storage of the DB instance",
            labels=["dbidentifier"],
            unit="bytes",
        )
        c.add_metric(labels=[instance["DBInstanceIdentifier"]], value=instance["MaxAllocatedStorage"] * 1024**3)
        yield c
        c = CounterMetricFamily(
            "rds_allocated_storage",
            "Allocated storage",
            labels=["dbidentifier"],
            unit="bytes"
        )
        c.add_metric(labels=[instance["DBInstanceIdentifier"]], value=instance["AllocatedStorage"] * 1024**3)
        yield c


def main():
    parser = argparse.ArgumentParser(
        prog='rds_metadata_exporter',
        description='What the program does'
    )
    parser.add_argument('region')
    parser.add_argument('dbinstance')
    parser.add_argument('-p', '--port', default=8000)
    args = parser.parse_args()

    # Start up the server exposing the metrics.
    rds_collector = RdsCollector(args.dbinstance, args.region)
    REGISTRY.register(rds_collector)
    start_wsgi_server(port=args.port)
    print(f"Start listening on port {args.port}")

    while True:
        time.sleep(1)


if __name__ == '__main__':
    main()
