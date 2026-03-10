import React, { Fragment, useState } from "react";
import 'bootstrap/dist/css/bootstrap.min.css';

const EditTodo = ({ todo }) => {
    const [description, setDescription] = useState(todo.description);
    const [show, setShow] = useState(false);

    const handleClose = () => {
        setDescription(todo.description); // reset on close
        setShow(false);
    };

    const updateDescription = async (e) => {
        e.preventDefault();
        try {
            const body = { description };
            await fetch(`/api/todos/${todo.todo_id}`, {
                method: "PUT",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(body),
            });

            window.location = "/";
        } catch (err) {
            console.error(err.message);
        }
    };

    return (
        <Fragment>
            <button
                type="button"
                className="btn btn-danger"
                onClick={() => setShow(true)}
            >
                Edit
            </button>

            {/* Backdrop */}
            {show && <div className="modal-backdrop fade show"></div>}

            <div
                className={`modal fade ${show ? "show d-block" : ""}`}
                tabIndex="-1"
            >
                <div className="modal-dialog">
                    <div className="modal-content">
                        <div className="modal-header">
                            <h4 className="modal-title">Edit Todo</h4>
                            <button
                                type="button"
                                className="btn-close"
                                onClick={handleClose}
                            />
                        </div>

                        <div className="modal-body">
                            <input
                                className="form-control"
                                type="text"
                                value={description}
                                onChange={(e) => setDescription(e.target.value)}
                            />
                        </div>

                        <div className="modal-footer">
                            <button
                                type="button"
                                className="btn btn-warning"
                                onClick={handleClose}
                            >
                                Close
                            </button>
                            <button
                                type="button"
                                className="btn btn-primary"
                                onClick={updateDescription}
                            >
                                Save
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </Fragment>
    );
};

export default EditTodo;
