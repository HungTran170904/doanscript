import { API_ENDPOINT } from "../Util/Constraint";
import AxiosService from "../Util/AxiosService";

const studentUrl = '/student';

export const enrollCourses = (courseIds) => {
    let formData = new FormData();
   formData.append('courseIds',JSON.stringify(courseIds))
    return AxiosService.post(API_ENDPOINT + studentUrl + '/enrollCourse', formData);
}

export const unenrollCourses = (courseIds) => {
    let formData = new FormData();
    formData.append('courseIds',JSON.stringify(courseIds))
    return AxiosService.post(API_ENDPOINT + studentUrl + '/unenrollCourse', formData);
}

export const getStudentInfo = () => {
    return AxiosService.get(API_ENDPOINT + studentUrl + '/studentInfo');
}

export const addStudent = (StudentDTO) => {
    return AxiosService.post(API_ENDPOINT + studentUrl + '/admin/addStudent', StudentDTO);
}

export const removeStudent = (id) => {
    return AxiosService.delete(API_ENDPOINT + studentUrl + '/admin/removeStudent/' + id);
}

export const getAllStudents=()=>{
    return AxiosService.get(API_ENDPOINT + studentUrl+"/admin/getAllStudents");
}

