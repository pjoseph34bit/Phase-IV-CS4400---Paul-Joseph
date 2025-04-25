import tkinter as tk
from tkinter import ttk, messagebox
import mysql.connector
import traceback

# Database connection
def connect_to_db():
    try:
        connection = mysql.connector.connect(
            host="localhost",
            user="root",
            password="Homer",
            database="flight_tracking"
        )
        print("Database connection successful!")  # Debug message
        return connection
    except mysql.connector.Error as err:
        messagebox.showerror("Database Error", f"Error: {err}")
        return None

# Call a stored procedure with parameters


def call_procedure(procedure_name, params):
    connection = connect_to_db()
    if connection:
        try:
            cursor = connection.cursor()
            cursor.callproc(procedure_name, params)
            connection.commit()
            messagebox.showinfo("Success", f"Procedure '{procedure_name}' executed successfully!")
            print(f"[SUCCESS] Executed {procedure_name} with params: {params}")
        except mysql.connector.Error as err:
            messagebox.showerror("Error", f"MySQL Error: {err}")
            print(f"[MySQL ERROR] {err}")
        except Exception as e:
            messagebox.showerror("Error", f"Unhandled Error: {e}")
            print("[UNHANDLED ERROR]")
            traceback.print_exc()
        finally:
            cursor.close()
            connection.close()


# Open an error screen
def open_error_screen(error_message):
    error_window = tk.Toplevel(root)
    error_window.title("Error")
    error_window.geometry("400x200")
    error_window.configure(bg="lightcoral")

    tk.Label(
        error_window,
        text=f"Sorry, please try again but {error_message} is invalid.",
        bg="lightcoral",
        fg="white",
        wraplength=350,
        font=("Arial", 12)
    ).pack(pady=20)

    tk.Button(
        error_window,
        text="OK",
        command=error_window.destroy,
        bg="white",
        fg="black"
    ).pack(pady=10)

# Validate inputs for constraints
def validate_inputs(procedure_name, params):
    if procedure_name == "add_airplane":
        required_fields = ["airline_id", "tail_num", "seat_capacity", "speed", "location_id"]
        for field in required_fields:
            if not params[field]:
                return f"{field.replace('_', ' ').title()} is required."
        if not params["seat_capacity"].isdigit() or int(params["seat_capacity"]) <= 0:
            return "Seat Capacity must be a positive number."
        if not params["speed"].isdigit() or int(params["speed"]) <= 0:
            return "Speed must be a positive number."

    elif procedure_name == "add_airport":
        required_fields = ["airport_id", "city", "state", "country", "location_id"]
        for field in required_fields:
            if not params[field]:
                return f"{field.replace('_', ' ').title()} is required."
        if len(params["airport_id"]) != 3:
            return "Airport ID must be exactly 3 characters."
        if len(params["country"]) != 3:
            return "Country code must be exactly 3 characters."

    elif procedure_name == "add_person":
        if not params["person_id"] or not params["first_name"] or not params["location_id"]:
            return "Person ID, First Name, and Location ID are required."
        if params["miles"] and (not params["miles"].isdigit() or int(params["miles"]) < 0):
            return "Miles must be a non-negative number."
        if params["funds"] and (not params["funds"].isdigit() or int(params["funds"]) < 0):
            return "Funds must be a non-negative number."
        if params["experience"] and (not params["experience"].isdigit() or int(params["experience"]) < 0):
            return "Experience must be a non-negative number."

    elif procedure_name == "offer_flight":
        required_fields = ["flight_id", "route_id", "next_time", "cost"]
        for field in required_fields:
            if not params[field]:
                return f"{field.replace('_', ' ').title()} is required."
        if not params["cost"].isdigit() or int(params["cost"]) <= 0:
            return "Cost must be a positive number."

    elif procedure_name in ["flight_landing", "flight_takeoff", "passengers_board", "passengers_disembark", "recycle_crew", "retire_flight"]:
        if not params["flight_id"]:
            return "Flight ID is required."

    elif procedure_name == "grant_or_revoke_pilot_license":
        if not params["person_id"] or not params["license"]:
            return "Person ID and License are required."

    elif procedure_name == "assign_pilot":
        if not params["flight_id"] or not params["person_id"]:
            return "Flight ID and Person ID are required."

    elif procedure_name == "simulation_cycle":
        # No parameters required for simulation_cycle
        pass

    return None

# Fetch data from a view
def fetch_view_data(view_name):
    connection = connect_to_db()
    if connection:
        try:
            cursor = connection.cursor()
            query = f"SELECT * FROM `{view_name}`"
            cursor.execute(query)
            columns = [desc[0] for desc in cursor.description]
            rows = cursor.fetchall()
        except mysql.connector.Error as err:
            messagebox.showerror("MySQL Error", f"Error: {err}")
            return [], []
        finally:
            cursor.close()
            connection.close()
        return columns, rows
    return [], []

# Display data in a table
def display_view_data(view_name, root):
    try:
        columns, rows = fetch_view_data(view_name)
        if not columns:
            messagebox.showinfo("No Data", f"No columns found for view: {view_name}", parent=root)
            return
        if not rows:
            messagebox.showinfo("No Data", f"No rows found for view: {view_name}", parent=root)
            return

        table_window = tk.Toplevel(root)
        table_window.title(f"View: {view_name}")
        tree = ttk.Treeview(table_window, columns=columns, show="headings")
        tree.pack(fill="both", expand=True)

        for col in columns:
            tree.heading(col, text=col)
            tree.column(col)

        for row in rows:
            tree.insert("", "end", values=row)

    except Exception as e:
        messagebox.showerror("Error", f"An error occurred while displaying the view: {e}")

# Open a GUI form for a procedure
def open_procedure_form(procedure_name, fields, button_label):
    form_window = tk.Toplevel(root)
    form_window.title(f"Procedure: {procedure_name}")
    form_window.geometry("400x600")
    form_window.configure(bg="lightblue")

    entries = {}
    for label_text, field_name in fields:
        tk.Label(form_window, text=label_text, bg="lightblue").pack(pady=5)
        entry = tk.Entry(form_window)
        entry.pack(pady=5)
        entries[field_name] = entry

    def add():
        try:
           params = {field_name: entry.get() for field_name, entry in entries.items()}
           validation_error = validate_inputs(procedure_name, params)
           if validation_error:
               open_error_screen(validation_error)
               return
           ordered_values = [params[field_name] for _, field_name in fields]
           call_procedure(procedure_name, ordered_values)
           validation_error = validate_inputs(procedure_name, params)
           if validation_error:
                open_error_screen(validation_error)
                return
           call_procedure(procedure_name, list(params.values()))
           form_window.destroy()
        except ValueError:
            open_error_screen("Please enter valid values for all fields.")

    def cancel():
        form_window.destroy()

    tk.Button(form_window, text=button_label, command=add).pack(pady=10)
    tk.Button(form_window, text="Cancel", command=cancel).pack(pady=10)

# Main GUI setup
root = tk.Tk()
root.title("Flight Tracking System")
root.geometry("400x800")
root.configure(bg="lightblue")

procedures = {
    "add_airplane": [
        ("Airline ID", "airline_id"),
        ("Tail Number", "tail_num"),
        ("Seat Capacity", "seat_capacity"),
        ("Speed", "speed"),
        ("Location ID", "location_id"),
        ("Plane Type", "plane_type"),
        ("Maintenanced (0 or 1)", "maintenanced"),
        ("Model", "model"),
        ("Neo (0 or 1)", "neo")
    ],
    "add_airport": [
        ("Airport ID", "airport_id"),
        ("Airport Name", "airport_name"),
        ("City", "city"),
        ("State", "state"),
        ("Country", "country"),
        ("Location ID", "location_id")
    ],
    "add_person": [
        ("Person ID", "person_id"),
        ("First Name", "first_name"),
        ("Last Name", "last_name"),
        ("Location ID", "location_id"),
        ("Tax ID", "tax_id"),
        ("Experience", "experience"),
        ("Miles", "miles"),
        ("Funds", "funds")
    ],
    "grant_or_revoke_pilot_license": [
        ("Person ID", "person_id"),
        ("License", "license")
    ],
    "offer_flight": [
        ("Flight ID", "flight_id"),
        ("Route ID", "route_id"),
        ("Support Airline", "support_airline"),
        ("Support Tail", "support_tail"),
        ("Progress", "progress"),
        ("Next Time", "next_time"),
        ("Cost", "cost")
    ],
    "flight_landing": [("Flight ID", "flight_id")],
    "flight_takeoff": [("Flight ID", "flight_id")],
    "passengers_board": [("Flight ID", "flight_id")],
    "passengers_disembark": [("Flight ID", "flight_id")],
    "assign_pilot": [("Flight ID", "flight_id"), ("Person ID", "person_id")],
    "recycle_crew": [("Flight ID", "flight_id")],
    "retire_flight": [("Flight ID", "flight_id")],
    "simulation_cycle": []
}

button_labels = {
    "grant_or_revoke_pilot_license": "Add/Revoke",
    "flight_landing": "Land",
    "flight_takeoff": "Takeoff",
    "passengers_board": "Board",
    "passengers_disembark": "Disembark",
    "recycle_crew": "Recycle",
    "retire_flight": "Retire",
    "simulation_cycle": "Next Step"
}

for procedure_name, fields in procedures.items():
    button_label = button_labels.get(procedure_name, "Add")
    tk.Button(
        root,
        text=procedure_name.replace("_", " ").title(),
        command=lambda p=procedure_name, f=fields, b=button_label: open_procedure_form(p, f, b)
    ).pack(pady=10)

views = [
    "flights_in_the_air",
    "flights_on_the_ground",
    "people_in_the_air",
    "people_on_the_ground",
    "route_summary",
    "alternative_airports"
]

tk.Label(root, text="Select a View:", bg="lightblue", font=("Arial", 12)).pack(pady=10)
view_dropdown = ttk.Combobox(root, values=views, state="readonly")
view_dropdown.pack(pady=10)

def on_view_select():
    selected_view = view_dropdown.get()
    if selected_view:
        display_view_data(selected_view, root)
    else:
        messagebox.showwarning("No Selection", "Please select a view to display.", parent=root)

tk.Button(root, text="Show View", command=on_view_select).pack(pady=10)

# Start the GUI loop
root.mainloop()