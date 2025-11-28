import { API_ENDPOINT } from "../Util/Constraint"
import { useState } from "react"
import { useSnackbar } from "notistack"
import { Link, useNavigate } from "react-router-dom"
import AxiosService from "../Util/AxiosService"
import UitIcon from "../Resourses/uit icon.png"

const Login=()=>{
          const navigate = useNavigate();
          const [form, setForm] = useState({
                    username: '',
                    password: ''
                })
          const { enqueueSnackbar } = useSnackbar();
          const [error,setError]=useState({ txtUsername: false, txtPassword: false });
          const onSubmit=()=>{
                    let validate = validateData(form)
                    let config = null;
                    let anchorOrigin = { horizontal: 'center' , vertical: 'bottom'}
                    if(validate){
                        const formData=new FormData();
                        formData.append('username', form.username)
                        formData.append('password', form.password)
                        AxiosService.post(API_ENDPOINT+'/api/auth/login',formData).then(res=>{
                            localStorage.setItem('Authorization', res.data.token);
                            localStorage.setItem('Role', res.data.role);
                            config = {variant: 'success',anchorOrigin:anchorOrigin}
                            enqueueSnackbar('Đăng nhập thành công', config);
                            let url="/";
                            if(res.data.role=="ADMIN") url="/admin/";
                            navigate(url);
                        })
                        .catch((error)=>{
                            config = {variant: 'error',anchorOrigin:anchorOrigin}
                            let errors = error.response;
                            if(errors==null) enqueueSnackbar('Unknown error', config);
                            else if (errors.status == 401) {
                                enqueueSnackbar('Tên tài khoản hoặc mật khẩu không chính xác', config);
                            }
                            else if(errors.status==400) enqueueSnackbar(errors.data, config);
                        })
                }
          }
          const handleChangeValue = (e) => {
                    let name = e.target.name;
                    let value = e.target.value;
                    if (name == 'username') {
                        setForm({ ...form, username: value })
                    }
                    if (name == 'password') {
                        setForm({ ...form, password: value })
                    }
                }
          const validateData = (data) => {
                    let isValid = true;
                    let txtUsername, txtPassword;
                    if (data.username.trim().length == 0) {
                        txtUsername = true;
                        isValid = false;
                    } else {
                        txtUsername = false;
                    }
                    if (data.password.trim().length == 0) {
                        isValid = false;
                        txtPassword = true;
                    } else {
                        txtPassword = false;
                    }
                    setError({ ...error, txtUsername: txtUsername, txtPassword: txtPassword })
                    return isValid;
          }
          return(
            <div className="OuterForm  py-4 bg-body-tertiary">
                <div className="form-signin w-100 m-auto text-center align-items-center">
                        <img className="mb-4" src={UitIcon} alt="" width="72" height="57"/>
                        <h1 className="h3 mb-3 fw-normal">Please sign in</h1>
                    <div className="form-floating">
                        <input type="text" className="form-control" id="exampleInputUsername" placeholder="Username" name="username" onChange={(e)=>handleChangeValue(e)}/> 
                        <label htmlFor="exampleInputUsername">Nhập MSSV hoặc email</label>
                    </div>
                        <div style={error.txtUsername ? { display: ''} : { display: 'none' }} className="error">
                                    Tên tài khoản không được để trống
                                </div>
                    <div className="form-floating">
                        <input type="password" className="form-control" id="exampleInputPassword1" placeholder="Password" name="password" onChange={(e)=>handleChangeValue(e)}/> 
                        <label htmlFor="exampleInputPassword1">Nhập mật khẩu</label>
                    </div>
                    <div style={error.txtPassword ? { display: ''} : { display: 'none' }} className="error">
                                Mật khẩu không được để trống
                        </div>
                    <button className="btn btn-primary w-100 py-2" onClick={()=>onSubmit()}>Đăng Nhập</button>
                    <Link to="#">Forgot password or username</Link><br/>
                    <p className="mt-2 mb-3 text-body-secondary">&copy; 2023–2050</p>
            </div>
        </div>
        )
}
export default Login;