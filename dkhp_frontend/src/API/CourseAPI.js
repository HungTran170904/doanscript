import { API_ENDPOINT } from "../Util/Constraint";
import AxiosService from "../Util/AxiosService";
import {SSE} from "sse.js"

const url='/courses';

export const getOpenedCourses=()=>{
          return AxiosService.get(API_ENDPOINT + url+'/openedCourses');
}

export const getEnrolledCourses=()=>{
          return AxiosService.get(API_ENDPOINT + url+'/enrolledCourses')
}

export const getStudiedCourses=(semesterId)=>{
          return AxiosService.get(API_ENDPOINT + url+'/enrolledCourses?semesterId='+semesterId)
}

export const addCourse=(CourseDTO)=>{
    return AxiosService.post(API_ENDPOINT + url+'/admin/addCourse',CourseDTO,true);
}

export const getAllCourses = () => {
    return AxiosService.get(API_ENDPOINT + url + '/admin/all');
}

export const removeCourse = (id) => {
    return AxiosService.delete(API_ENDPOINT + url + '/admin/removeCourse/' + id);
}

export const getUpdatedRegNumbers=(setRegNumbers)=>{
    var sseClient= new SSE(API_ENDPOINT + url +"/updateRegNumbers",{
      headers:{Authorization: localStorage.getItem("Authorization")}
    });
    sseClient.addEventListener("message",(e)=>{
        var jsonObject=JSON.parse(e.data);
        var updatedRegNumbers=new Map(Object.entries(jsonObject));
        //console.log("Reg numbers",updatedRegNumbers);
        setRegNumbers(updatedRegNumbers);
    })
    sseClient.addEventListener("error",(err)=>{
        console.log("Error "+err);
    })
    return sseClient;
}