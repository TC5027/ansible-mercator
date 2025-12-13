## Ansible’s Python API DOES NOT expose group vars in a universal way unless you resolve variables for a host.
## aussi dire ya .yml hardcode
import yaml
import click
import os
import sys
from ansible_mercator import __version__
from ansible.parsing.dataloader import DataLoader
from ansible.inventory.manager import InventoryManager

def load_yaml_file(path: str) -> dict:
    try:
        with open(path) as f:
            data = yaml.safe_load(f) or {}
    except FileNotFoundError as exc:
        raise RuntimeError(f"File not found: {path}") from exc
    except yaml.YAMLError as exc:
        raise RuntimeError(f"Invalid YAML in {path}") from exc

    if not isinstance(data, dict):
        raise RuntimeError(f"{path} must contain a YAML mapping")

    return data



@click.version_option(__version__, '-V', '--version')
@click.option('--cartography', required=True, type=click.Path(exists=True), help='Path to your cartography')
@click.option('--inventory', required=True, type=click.Path(exists=True), help='Path to your inventory')
@click.option('--group_vars', required=True, type=click.Path(exists=True), help='Path to your group_vars folder')
@click.command()
def main(cartography, inventory, group_vars):
    try:
        loader = DataLoader()
        inventory_manager = InventoryManager(loader=loader, sources=[inventory])

        cartography_loaded = load_yaml_file(cartography)

        group_vars_files = {
            f for f in os.listdir(group_vars)
            if os.path.isfile(os.path.join(group_vars, f))
        }

        for level, variables in cartography_loaded.items():
            if level not in inventory_manager.groups:
                raise RuntimeError(f"Unknown inventory group: {level}")

            required = {
                f"{cg}.yml"
                for cg in inventory_manager.groups[level].child_groups
            }
            forbidden = group_vars_files - required

            for file in required:
                vars_data = load_yaml_file(os.path.join(group_vars, file))
                for variable in variables:
                    if variable not in vars_data:
                        raise RuntimeError(f"MISSING {variable} in {file}")

            for file in forbidden:
                vars_data = load_yaml_file(os.path.join(group_vars, file))
                for variable in variables:
                    if variable in vars_data:
                        raise RuntimeError(
                            f"INCORRECT LOCATION {variable} in {file}"
                        )

    except RuntimeError as exc:
        click.echo(f"ERROR: {exc}", err=True)
        raise SystemExit(1)

    click.echo("all good")

