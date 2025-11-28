import React, { useContext, useEffect, useState } from "react";
import { Link } from "react-router-dom"
const AdminNavBar = () => {
    return (
        <nav className="navbar navbar-expand-lg navbar-light bg-light h6">
            <Link className="navbar-brand" to="/admin/">Course Registration App</Link>
            <div className="collapse navbar-collapse" id="navbarText">
                <ul className="navbar-nav mr-auto">
                    <li className="nav-item active">
                        <Link className="nav-link" to="/admin/CoursePage">All Courses</Link>
                    </li>
                    <li className="nav-item">
                        <Link className="nav-link" to="/admin/SubjectPage">All Subjects</Link>
                    </li>
                    <li className="nav-item">
                        <Link className="nav-link" to="/admin/StudentPage">All Students</Link>
                    </li>
                    <li className="nav-item">
                        <Link className="nav-link" to="/admin/OpeningRegPeriod">OpeningRegPeriod</Link>
                    </li>
                    <li className="nav-item">
                        <Link className="nav-link" to="/admin/SemesterPage">All Semesters</Link>
                    </li>
                    <li  className="nav-item">
                      <Link className="nav-link" to="/login" onClick={()=>{localStorage.removeItem("Authorization")}}>Logout</Link>
                    </li>
                </ul>
            </div>
        </nav>
    );
}

export default AdminNavBar;