import { Link } from "react-router-dom";

const ErrorPage = ({message}) =>(
            <div
                style={{
                    display: "flex",
                    flexDirection: "column",
                    justifyContent: "center",
                    alignItems: "center",
                    marginTop: "20%",
                }}
            >
                <h2 style={{ marginBottom: "20px" }}>{message}</h2>
                <Link to="/login">Go to Login Page</Link>
            </div>
    )

export default ErrorPage;