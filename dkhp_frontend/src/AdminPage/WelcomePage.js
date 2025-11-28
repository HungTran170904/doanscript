import React from "react";
import { Link } from "react-router-dom";

const WelcomePage = () => (
    <div
        style={{
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            alignItems: "center",
            marginTop: "20%",
            gap: "15px"
        }}
    >
        <h1 style={{ marginBottom: "20px" }}>Welcome to the Course Registration App!</h1>
        <Link to="/admin/CoursePage">Go to Courses Page</Link>
        <Link to="/admin/SubjectPage">Go to Subjects Page</Link>
        <Link to="/admin/StudentPage">Go to Students Page</Link>
    </div>
);

export default WelcomePage;