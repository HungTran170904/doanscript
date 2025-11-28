import { jwtDecode } from "jwt-decode";
import { Navigate } from "react-router-dom";
const isExpiredToken=(token)=>{
        const decodedToken = jwtDecode(token);
        const now=new Date();
        return (decodedToken.exp * 1000 < now.getTime());
}
const ProtectedRouter=({requiredRole, children})=>{
        const token=localStorage.getItem('Authorization');
        const role=localStorage.getItem('Role');
        if(token&&!isExpiredToken(token)&&role&&role===requiredRole) return children;
        else{
            return(<Navigate replace to="/login" />)
        }
}
export default ProtectedRouter;